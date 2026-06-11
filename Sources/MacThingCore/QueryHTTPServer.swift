import Darwin
import Foundation

public final class QueryHTTPServer: @unchecked Sendable {
    public struct Status: Encodable, Sendable {
        public let rootPath: String
        public let indexedCount: Int
        public let resultCount: Int
        public let lastIndexedAt: Date?
        public let statusText: String
        public let isIndexing: Bool

        public init(
            rootPath: String,
            indexedCount: Int,
            resultCount: Int,
            lastIndexedAt: Date?,
            statusText: String = "",
            isIndexing: Bool = false
        ) {
            self.rootPath = rootPath
            self.indexedCount = indexedCount
            self.resultCount = resultCount
            self.lastIndexedAt = lastIndexedAt
            self.statusText = statusText
            self.isIndexing = isIndexing
        }
    }

    private struct SearchPayload: Encodable {
        let query: String
        let totalMatches: Int
        let limit: Int
        let offset: Int
        let warnings: [String]
        let sortField: SearchSortField
        let sortDirection: SearchSortDirection
        let results: [FileEntry]
        let columns: [String]?
        let rows: [[String: String]]?
    }

    private enum SearchResponseFormat: String {
        case json
        case csv
        case txt
        case efu
    }

    private struct ParsedSearchRequest {
        let query: String
        let request: SearchRequest
        let format: SearchResponseFormat
        let columns: [ResultExportColumn]
        let includeRows: Bool
    }

    public typealias SearchHandler = (SearchRequest) -> SearchResponse
    public typealias StatusHandler = () -> Status

    private let port: UInt16
    private let searchHandler: SearchHandler
    private let statusHandler: StatusHandler
    private var socketFD: Int32 = -1
    private var isRunning = false
    private let queue = DispatchQueue(label: "MacThing.QueryHTTPServer", qos: .utility)
    private let clientQueue = DispatchQueue(
        label: "MacThing.QueryHTTPServer.clients",
        qos: .userInitiated,
        attributes: .concurrent
    )

    public init(
        port: UInt16,
        searchHandler: @escaping SearchHandler,
        statusHandler: @escaping StatusHandler
    ) throws {
        self.port = port
        self.searchHandler = searchHandler
        self.statusHandler = statusHandler
        try start()
    }

    deinit {
        stop()
    }

    public func stop() {
        isRunning = false
        if socketFD >= 0 {
            Darwin.shutdown(socketFD, SHUT_RDWR)
            Darwin.close(socketFD)
            socketFD = -1
        }
    }

    private func start() throws {
        socketFD = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD >= 0 else {
            throw QueryHTTPServerError.socketError(Self.errnoMessage())
        }

        var reuse: Int32 = 1
        setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.bind(socketFD, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            throw QueryHTTPServerError.socketError(Self.errnoMessage())
        }

        guard Darwin.listen(socketFD, 16) == 0 else {
            throw QueryHTTPServerError.socketError(Self.errnoMessage())
        }

        isRunning = true
        queue.async { [self] in
            acceptLoop()
        }
    }

    private func acceptLoop() {
        while isRunning {
            let clientFD = Darwin.accept(socketFD, nil, nil)
            if clientFD < 0 {
                continue
            }
            clientQueue.async { [self] in
                receiveRequest(from: clientFD)
            }
        }
    }

    private func receiveRequest(from clientFD: Int32) {
        guard let request = readHTTPRequest(from: clientFD) else {
            Darwin.close(clientFD)
            return
        }
        let response = handle(request: request)
        write(response.data, to: clientFD)
        Darwin.close(clientFD)
    }

    private func readHTTPRequest(from clientFD: Int32) -> String? {
        let flags = fcntl(clientFD, F_GETFL, 0)
        if flags >= 0 {
            _ = fcntl(clientFD, F_SETFL, flags | O_NONBLOCK)
        }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        let deadline = Date().addingTimeInterval(5)

        while Date() < deadline, data.count < 64 * 1_024 {
            let count = buffer.withUnsafeMutableBytes { rawBuffer in
                Darwin.recv(clientFD, rawBuffer.baseAddress, rawBuffer.count, 0)
            }

            if count > 0 {
                data.append(buffer, count: count)
                if data.range(of: Data("\r\n\r\n".utf8)) != nil {
                    break
                }
            } else if count == 0 {
                break
            } else if errno == EAGAIN || errno == EWOULDBLOCK {
                usleep(10_000)
            } else {
                break
            }
        }

        guard !data.isEmpty else {
            return nil
        }

        return String(decoding: data, as: UTF8.self)
    }

    private func handle(request: String) -> HTTPResponse {
        guard let firstLine = request.split(separator: "\r\n").first else {
            return .badRequest("Missing request line")
        }

        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" else {
            return .methodNotAllowed
        }

        guard let components = URLComponents(string: "http://127.0.0.1\(parts[1])") else {
            return .badRequest("Invalid URL")
        }

        switch components.path {
        case "/api/status":
            return json(statusHandler())
        case "/api/search":
            let parsedRequest = parseSearchRequest(components: components)
            let response = searchHandler(parsedRequest.request)
            return searchHTTPResponse(response, parsedRequest: parsedRequest)
        default:
            return .notFound
        }
    }

    private func parseSearchRequest(components: URLComponents) -> ParsedSearchRequest {
        let queryItems = components.queryItems ?? []

        func value(_ name: String) -> String? {
            queryItems.first { $0.name == name }?.value
        }

        let query = value("q") ?? ""
        let limit = value("limit").flatMap(Int.init) ?? 100
        let offset = value("offset").flatMap(Int.init) ?? 0
        let sortField = parseSortField(value("sort")) ?? .relevance
        let sortDirection = parseSortDirection(value("order")) ?? parseSortDirection(value("direction")) ?? .ascending
        let options = SearchOptions(
            matchPath: parseBool(value("matchPath")) ?? parseBool(value("path")) ?? true,
            fuzzyMatching: parseBool(value("fuzzy")) ?? true,
            caseSensitive: parseBool(value("case")) ?? parseBool(value("caseSensitive")) ?? false,
            regexMatching: parseBool(value("regex")) ?? parseBool(value("regexMatching")) ?? false,
            wholeWordMatching: parseBool(value("wholeWord")) ?? parseBool(value("whole")) ?? false,
            diacriticSensitive: parseBool(value("diacritics")) ??
                parseBool(value("diacritic")) ??
                parseBool(value("matchDiacritics")) ??
                false
        )
        let columnsValue = value("columns")
        let columns = ResultExportColumn.parseList(columnsValue)
        let format = value("format").flatMap(SearchResponseFormat.init(rawValue:)) ?? .json

        return ParsedSearchRequest(
            query: query,
            request: SearchRequest(
                query: query,
                limit: max(1, min(limit, 2_000)),
                offset: max(0, offset),
                sortField: sortField,
                sortDirection: sortDirection,
                options: options
            ),
            format: format,
            columns: columns,
            includeRows: columnsValue != nil
        )
    }

    private func searchHTTPResponse(
        _ response: SearchResponse,
        parsedRequest: ParsedSearchRequest
    ) -> HTTPResponse {
        switch parsedRequest.format {
        case .json:
            return json(
                SearchPayload(
                    query: parsedRequest.query,
                    totalMatches: response.totalMatches,
                    limit: parsedRequest.request.limit,
                    offset: parsedRequest.request.offset,
                    warnings: response.warnings,
                    sortField: parsedRequest.request.sortField,
                    sortDirection: parsedRequest.request.sortDirection,
                    results: response.entries,
                    columns: parsedRequest.includeRows ? parsedRequest.columns.map(\.rawValue) : nil,
                    rows: parsedRequest.includeRows
                        ? ResultExporter.rows(entries: response.entries, columns: parsedRequest.columns)
                        : nil
                )
            )
        case .csv:
            return .ok(
                Data(ResultExporter.csv(entries: response.entries, columns: parsedRequest.columns).utf8),
                contentType: "text/csv; charset=utf-8"
            )
        case .txt:
            return .ok(
                Data(ResultExporter.text(entries: response.entries).utf8),
                contentType: "text/plain; charset=utf-8"
            )
        case .efu:
            return .ok(
                Data(ResultExporter.efu(entries: response.entries).utf8),
                contentType: "text/csv; charset=utf-8"
            )
        }
    }

    private func parseSortField(_ value: String?) -> SearchSortField? {
        guard let value else {
            return nil
        }
        return SearchSortField.parse(value)
    }

    private func parseSortDirection(_ value: String?) -> SearchSortDirection? {
        switch value?.lowercased() {
        case "asc", "ascending":
            return .ascending
        case "desc", "descending":
            return .descending
        default:
            return nil
        }
    }

    private func parseBool(_ value: String?) -> Bool? {
        switch value?.lowercased() {
        case "1", "true", "yes", "on":
            return true
        case "0", "false", "no", "off":
            return false
        default:
            return nil
        }
    }

    private func json<Value: Encodable>(_ value: Value) -> HTTPResponse {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(value)
            return .ok(data, contentType: "application/json")
        } catch {
            return .serverError("Could not encode response")
        }
    }

    private func write(_ data: Data, to clientFD: Int32) {
        data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return
            }

            var remaining = data.count
            var offset = 0
            while remaining > 0 {
                let written = Darwin.write(clientFD, baseAddress.advanced(by: offset), remaining)
                if written <= 0 {
                    break
                }
                offset += written
                remaining -= written
            }
        }
    }

    private static func errnoMessage() -> String {
        String(cString: strerror(errno))
    }
}

private enum QueryHTTPServerError: Error {
    case socketError(String)
}

private struct HTTPResponse {
    let status: String
    let contentType: String
    let body: Data

    var data: Data {
        let headers = "HTTP/1.0 \(status)\r\n" +
            "Content-Type: \(contentType)\r\n" +
            "Access-Control-Allow-Origin: http://127.0.0.1\r\n" +
            "Connection: close\r\n" +
            "\r\n"

        var data = Data(headers.utf8)
        data.append(body)
        return data
    }

    static func ok(_ body: Data, contentType: String) -> HTTPResponse {
        HTTPResponse(status: "200 OK", contentType: contentType, body: body)
    }

    static func badRequest(_ message: String) -> HTTPResponse {
        text(status: "400 Bad Request", message: message)
    }

    static var notFound: HTTPResponse {
        text(status: "404 Not Found", message: "Not found")
    }

    static var methodNotAllowed: HTTPResponse {
        text(status: "405 Method Not Allowed", message: "Method not allowed")
    }

    static func serverError(_ message: String) -> HTTPResponse {
        text(status: "500 Internal Server Error", message: message)
    }

    private static func text(status: String, message: String) -> HTTPResponse {
        HTTPResponse(status: status, contentType: "text/plain; charset=utf-8", body: Data(message.utf8))
    }
}
