import Darwin
import Foundation

@main
struct MacThingCLI {
    static func main() async {
        do {
            let command = try CommandLineParser.parse(Array(CommandLine.arguments.dropFirst()))
            if command.shouldPrintHelp {
                printHelp()
                return
            }

            let url = try command.url()
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CLIError("No HTTP response")
            }
            guard 200..<300 ~= httpResponse.statusCode else {
                let body = String(decoding: data, as: UTF8.self)
                throw CLIError("HTTP \(httpResponse.statusCode): \(body)")
            }

            FileHandle.standardOutput.write(data)
            if data.last != UInt8(ascii: "\n") {
                print()
            }
        } catch {
            fputs("MacThingCLI: \(error.localizedDescription)\n", stderr)
            fputs("Run `swift run MacThingCLI -- help` for usage.\n", stderr)
            exit(1)
        }
    }

    private static func printHelp() {
        print("""
        Usage:
          swift run MacThingCLI -- status [--port 16245]
          swift run MacThingCLI -- search <query> [options]

        Search options:
          --limit <n>, -n <n>, --max-results <n>
                              Maximum results, default 100
          --offset <n>, -o <n>
                              Skip the first n results
          --sort <field>       relevance, name, path, extension, kind, size, dateModified, dateCreated, dateAccessed, dateIndexed, runCount, dateRun, attributes
          --order <dir>        asc or desc
          --format <format>    json, csv, txt, or efu
          -sort <field>, -order <dir>, -csv, -txt, -efu, -json
                              Everything es.exe-style aliases
          --columns <list>     Comma-separated export columns such as name,path,extension,size,dateModified,fileID
          --path / --no-path   Enable or disable path matching
          --fuzzy / --no-fuzzy Enable or disable fuzzy matching
          --case / --no-case   Enable or disable case-sensitive matching
          --whole-word / --no-whole-word
                              Enable or disable whole-word matching
          --diacritics / --no-diacritics
                              Enable or disable diacritic-sensitive matching
          --port <port>        Query service port, default 16245
        """)
    }
}

private struct CLICommand {
    var endpoint: String
    var port: Int
    var queryItems: [URLQueryItem]
    var shouldPrintHelp = false

    func url() throws -> URL {
        var components = URLComponents()
        components.scheme = "http"
        components.host = "127.0.0.1"
        components.port = port
        components.path = endpoint
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw CLIError("Could not build request URL")
        }
        return url
    }
}

private enum CommandLineParser {
    static func parse(_ arguments: [String]) throws -> CLICommand {
        var arguments = arguments
        if arguments.first == "--" {
            arguments.removeFirst()
        }
        guard let command = arguments.first else {
            return CLICommand(endpoint: "", port: 16245, queryItems: [], shouldPrintHelp: true)
        }
        arguments.removeFirst()

        switch command {
        case "help", "--help", "-h":
            return CLICommand(endpoint: "", port: 16245, queryItems: [], shouldPrintHelp: true)
        case "status":
            return try parseStatus(arguments)
        case "search":
            return try parseSearch(arguments)
        default:
            throw CLIError("Unknown command `\(command)`")
        }
    }

    private static func parseStatus(_ arguments: [String]) throws -> CLICommand {
        var port = 16245
        var cursor = 0
        while cursor < arguments.count {
            switch arguments[cursor] {
            case "--port":
                port = try intValue(after: &cursor, in: arguments, option: "--port")
            default:
                throw CLIError("Unknown status option `\(arguments[cursor])`")
            }
            cursor += 1
        }

        return CLICommand(endpoint: "/api/status", port: port, queryItems: [])
    }

    private static func parseSearch(_ arguments: [String]) throws -> CLICommand {
        var port = 16245
        var queryParts: [String] = []
        var queryItems: [URLQueryItem] = []
        var cursor = 0

        while cursor < arguments.count {
            let argument = arguments[cursor]
            switch argument {
            case "--port":
                port = try intValue(after: &cursor, in: arguments, option: argument)
            case "--limit", "--sort", "--order", "--format", "--columns", "--offset":
                queryItems.append(URLQueryItem(
                    name: String(argument.dropFirst(2)),
                    value: try stringValue(after: &cursor, in: arguments, option: argument)
                ))
            case "-sort", "-order", "-format", "-columns":
                queryItems.append(URLQueryItem(
                    name: String(argument.dropFirst()),
                    value: try stringValue(after: &cursor, in: arguments, option: argument)
                ))
            case "-n", "--max-results":
                queryItems.append(URLQueryItem(
                    name: "limit",
                    value: try stringValue(after: &cursor, in: arguments, option: argument)
                ))
            case "-o":
                queryItems.append(URLQueryItem(
                    name: "offset",
                    value: try stringValue(after: &cursor, in: arguments, option: argument)
                ))
            case "-csv", "--csv":
                queryItems.append(URLQueryItem(name: "format", value: "csv"))
            case "-txt", "--txt":
                queryItems.append(URLQueryItem(name: "format", value: "txt"))
            case "-efu", "--efu":
                queryItems.append(URLQueryItem(name: "format", value: "efu"))
            case "-json", "--json":
                queryItems.append(URLQueryItem(name: "format", value: "json"))
            case "--path":
                queryItems.append(URLQueryItem(name: "path", value: "true"))
            case "--no-path":
                queryItems.append(URLQueryItem(name: "path", value: "false"))
            case "--fuzzy":
                queryItems.append(URLQueryItem(name: "fuzzy", value: "true"))
            case "--no-fuzzy":
                queryItems.append(URLQueryItem(name: "fuzzy", value: "false"))
            case "--case":
                queryItems.append(URLQueryItem(name: "case", value: "true"))
            case "--no-case":
                queryItems.append(URLQueryItem(name: "case", value: "false"))
            case "--whole-word", "--whole":
                queryItems.append(URLQueryItem(name: "wholeWord", value: "true"))
            case "--no-whole-word", "--no-whole":
                queryItems.append(URLQueryItem(name: "wholeWord", value: "false"))
            case "--diacritics", "--diacritic":
                queryItems.append(URLQueryItem(name: "diacritics", value: "true"))
            case "--no-diacritics", "--no-diacritic":
                queryItems.append(URLQueryItem(name: "diacritics", value: "false"))
            default:
                if argument.hasPrefix("--") {
                    throw CLIError("Unknown search option `\(argument)`")
                }
                queryParts.append(argument)
            }
            cursor += 1
        }

        queryItems.insert(URLQueryItem(name: "q", value: queryParts.joined(separator: " ")), at: 0)
        return CLICommand(endpoint: "/api/search", port: port, queryItems: queryItems)
    }

    private static func stringValue(after cursor: inout Int, in arguments: [String], option: String) throws -> String {
        let valueIndex = cursor + 1
        guard valueIndex < arguments.count else {
            throw CLIError("Missing value for \(option)")
        }
        cursor = valueIndex
        return arguments[valueIndex]
    }

    private static func intValue(after cursor: inout Int, in arguments: [String], option: String) throws -> Int {
        let rawValue = try stringValue(after: &cursor, in: arguments, option: option)
        guard let value = Int(rawValue) else {
            throw CLIError("Invalid integer for \(option): \(rawValue)")
        }
        return value
    }
}

private struct CLIError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}
