import Darwin
import Foundation

public final class QueryHTTPServer: @unchecked Sendable {
    public struct Configuration: Equatable, Sendable {
        public enum CORSPolicy: Equatable, Sendable {
            case disabled
            case loopback
            case custom(String)
        }

        public let authorizationToken: String?
        public let corsPolicy: CORSPolicy

        public init(
            authorizationToken: String? = nil,
            corsPolicy: CORSPolicy = .loopback
        ) {
            let trimmedToken = authorizationToken?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.authorizationToken = trimmedToken?.isEmpty == false ? trimmedToken : nil

            if case let .custom(origin) = corsPolicy,
               let normalizedOrigin = Self.normalizedOrigin(origin) {
                self.corsPolicy = .custom(normalizedOrigin)
            } else if case .custom = corsPolicy {
                self.corsPolicy = .disabled
            } else {
                self.corsPolicy = corsPolicy
            }
        }

        public static func normalizedOrigin(_ rawOrigin: String) -> String? {
            let origin = rawOrigin.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !origin.isEmpty,
                  !origin.contains("\r"),
                  !origin.contains("\n"),
                  let components = URLComponents(string: origin),
                  let rawScheme = components.scheme,
                  let rawHost = components.host,
                  !rawHost.isEmpty,
                  components.user == nil,
                  components.password == nil,
                  components.query == nil,
                  components.fragment == nil,
                  components.path.isEmpty || components.path == "/" else {
                return nil
            }

            let scheme = rawScheme.lowercased()
            guard scheme == "http" || scheme == "https" else {
                return nil
            }

            var normalized = URLComponents()
            normalized.scheme = scheme
            normalized.host = rawHost.lowercased()
            let isDefaultPort = (scheme == "http" && components.port == 80) ||
                (scheme == "https" && components.port == 443)
            normalized.port = isDefaultPort ? nil : components.port
            return normalized.string
        }

        fileprivate func allowedOrigin(for rawOrigin: String) -> String? {
            guard let origin = Self.normalizedOrigin(rawOrigin) else {
                return nil
            }

            switch corsPolicy {
            case .disabled:
                return nil
            case .loopback:
                guard let host = URLComponents(string: origin)?.host?.lowercased(),
                      host == "localhost" || host == "127.0.0.1" || host == "::1" else {
                    return nil
                }
                return origin
            case let .custom(allowedOrigin):
                return origin == allowedOrigin ? origin : nil
            }
        }
    }

    public struct Status: Encodable, Sendable {
        public let rootPath: String
        public let indexedCount: Int
        public let resultCount: Int
        public let lastIndexedAt: Date?
        public let statusText: String
        public let isIndexing: Bool
        public let isLoadingIndex: Bool
        public let isSearching: Bool
        public let indexFreshnessWarning: String?
        public let lastSearch: SearchDiagnostics?

        public init(
            rootPath: String,
            indexedCount: Int,
            resultCount: Int,
            lastIndexedAt: Date?,
            statusText: String = "",
            isIndexing: Bool = false,
            isLoadingIndex: Bool = false,
            isSearching: Bool = false,
            indexFreshnessWarning: String? = nil,
            lastSearch: SearchDiagnostics? = nil
        ) {
            self.rootPath = rootPath
            self.indexedCount = indexedCount
            self.resultCount = resultCount
            self.lastIndexedAt = lastIndexedAt
            self.statusText = statusText
            self.isIndexing = isIndexing
            self.isLoadingIndex = isLoadingIndex
            self.isSearching = isSearching
            self.indexFreshnessWarning = indexFreshnessWarning
            self.lastSearch = lastSearch
        }
    }

    private struct SearchPayload: Encodable {
        let query: String
        let totalMatches: Int
        let limit: Int
        let offset: Int
        let warnings: [String]
        let diagnostics: SearchDiagnostics?
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

    private struct ParsedHTTPRequest {
        let method: String
        let target: String
        let headers: [String: String]

        init?(rawRequest: String) {
            let lines = rawRequest.components(separatedBy: "\r\n")
            guard let requestLine = lines.first else {
                return nil
            }

            let requestParts = requestLine.split(separator: " ", maxSplits: 2)
            guard requestParts.count == 3,
                  requestParts[2].hasPrefix("HTTP/") else {
                return nil
            }

            method = requestParts[0].uppercased()
            target = String(requestParts[1])
            guard target.hasPrefix("/") else {
                return nil
            }

            var parsedHeaders: [String: String] = [:]
            for line in lines.dropFirst() where !line.isEmpty {
                guard let separator = line.firstIndex(of: ":") else {
                    continue
                }
                let name = line[..<separator]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                let value = line[line.index(after: separator)...]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, parsedHeaders[name] == nil else {
                    continue
                }
                parsedHeaders[name] = value
            }
            headers = parsedHeaders
        }
    }

    public typealias SearchHandler = (SearchRequest) -> SearchResponse
    public typealias StatusHandler = () -> Status

    private let port: UInt16
    private let configuration: Configuration
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
        configuration: Configuration = Configuration(),
        searchHandler: @escaping SearchHandler,
        statusHandler: @escaping StatusHandler
    ) throws {
        self.port = port
        self.configuration = configuration
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
            let message = Self.errnoMessage()
            Darwin.close(socketFD)
            socketFD = -1
            throw QueryHTTPServerError.socketError(message)
        }

        guard Darwin.listen(socketFD, 16) == 0 else {
            let message = Self.errnoMessage()
            Darwin.close(socketFD)
            socketFD = -1
            throw QueryHTTPServerError.socketError(message)
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
        var noPipe: Int32 = 1
        setsockopt(clientFD, SOL_SOCKET, SO_NOSIGPIPE, &noPipe, socklen_t(MemoryLayout<Int32>.size))

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
        guard let request = ParsedHTTPRequest(rawRequest: request) else {
            return .badRequest("Invalid HTTP request")
        }

        var responseHeaders: [String: String] = [:]
        if let requestOrigin = request.headers["origin"] {
            guard let allowedOrigin = configuration.allowedOrigin(for: requestOrigin) else {
                return .forbidden("Origin not allowed")
            }
            responseHeaders["Access-Control-Allow-Origin"] = allowedOrigin
            responseHeaders["Vary"] = "Origin"
        }

        if request.method == "OPTIONS" {
            guard request.headers["origin"] != nil,
                  request.headers["access-control-request-method"]?.uppercased() == "GET" else {
                return HTTPResponse.badRequest("Invalid preflight request")
                    .adding(headers: responseHeaders)
            }
            responseHeaders["Access-Control-Allow-Methods"] = "GET, OPTIONS"
            responseHeaders["Access-Control-Allow-Headers"] = "Authorization, Content-Type"
            responseHeaders["Access-Control-Max-Age"] = "600"
            return .noContent.adding(headers: responseHeaders)
        }

        guard request.method == "GET" else {
            return HTTPResponse.methodNotAllowed.adding(headers: responseHeaders)
        }

        guard isAuthorized(request.headers["authorization"]) else {
            return HTTPResponse.unauthorized.adding(headers: responseHeaders)
        }

        guard let components = URLComponents(string: "http://127.0.0.1\(request.target)") else {
            return HTTPResponse.badRequest("Invalid URL").adding(headers: responseHeaders)
        }

        let response: HTTPResponse
        switch components.path {
        case "/api/status":
            response = json(statusHandler())
        case "/api/search":
            let parsedRequest = parseSearchRequest(components: components)
            let searchResponse = searchHandler(parsedRequest.request)
            response = searchHTTPResponse(searchResponse, parsedRequest: parsedRequest)
        default:
            response = .notFound
        }
        return response.adding(headers: responseHeaders)
    }

    private func isAuthorized(_ authorizationHeader: String?) -> Bool {
        guard let expectedToken = configuration.authorizationToken else {
            return true
        }
        guard let authorizationHeader else {
            return false
        }

        let parts = authorizationHeader.split(
            maxSplits: 1,
            omittingEmptySubsequences: true,
            whereSeparator: \.isWhitespace
        )
        guard parts.count == 2,
              String(parts[0]).caseInsensitiveCompare("Bearer") == .orderedSame else {
            return false
        }
        return Self.constantTimeEqual(String(parts[1]), expectedToken)
    }

    private static func constantTimeEqual(_ lhs: String, _ rhs: String) -> Bool {
        let left = Array(lhs.utf8)
        let right = Array(rhs.utf8)
        let count = max(left.count, right.count)
        var difference = left.count ^ right.count

        for index in 0..<count {
            let leftByte = index < left.count ? left[index] : 0
            let rightByte = index < right.count ? right[index] : 0
            difference |= Int(leftByte ^ rightByte)
        }
        return difference == 0
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
                    diagnostics: response.diagnostics,
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

private enum QueryHTTPServerError: LocalizedError {
    case socketError(String)

    var errorDescription: String? {
        switch self {
        case let .socketError(message):
            return message
        }
    }
}

private struct HTTPResponse {
    let status: String
    let contentType: String
    let body: Data
    let headers: [String: String]

    var data: Data {
        var responseHeaders = headers
        responseHeaders["Connection"] = "close"
        responseHeaders["Content-Length"] = String(body.count)
        responseHeaders["Content-Type"] = contentType

        let serializedHeaders = responseHeaders
            .sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
            .map { "\($0.key): \($0.value)\r\n" }
            .joined()
        let headerData = "HTTP/1.1 \(status)\r\n" + serializedHeaders + "\r\n"

        var data = Data(headerData.utf8)
        data.append(body)
        return data
    }

    static func ok(_ body: Data, contentType: String) -> HTTPResponse {
        HTTPResponse(status: "200 OK", contentType: contentType, body: body, headers: [:])
    }

    static func badRequest(_ message: String) -> HTTPResponse {
        text(status: "400 Bad Request", message: message)
    }

    static var notFound: HTTPResponse {
        text(status: "404 Not Found", message: "Not found")
    }

    static func forbidden(_ message: String) -> HTTPResponse {
        text(status: "403 Forbidden", message: message)
    }

    static var unauthorized: HTTPResponse {
        text(status: "401 Unauthorized", message: "Authorization required")
            .adding(headers: ["WWW-Authenticate": "Bearer realm=\"MacThing\""])
    }

    static var methodNotAllowed: HTTPResponse {
        text(status: "405 Method Not Allowed", message: "Method not allowed")
            .adding(headers: ["Allow": "GET, OPTIONS"])
    }

    static var noContent: HTTPResponse {
        HTTPResponse(
            status: "204 No Content",
            contentType: "text/plain; charset=utf-8",
            body: Data(),
            headers: [:]
        )
    }

    static func serverError(_ message: String) -> HTTPResponse {
        text(status: "500 Internal Server Error", message: message)
    }

    private static func text(status: String, message: String) -> HTTPResponse {
        HTTPResponse(
            status: status,
            contentType: "text/plain; charset=utf-8",
            body: Data(message.utf8),
            headers: [:]
        )
    }

    func adding(headers newHeaders: [String: String]) -> HTTPResponse {
        var mergedHeaders = headers
        for (name, value) in newHeaders {
            mergedHeaders[name] = value
        }
        return HTTPResponse(
            status: status,
            contentType: contentType,
            body: body,
            headers: mergedHeaders
        )
    }
}
