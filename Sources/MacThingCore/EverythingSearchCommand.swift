import Foundation

public enum EverythingSearchCommand: Equatable, Sendable {
    case close
    case closeAll
    case quit
    case rebuild
    case update(path: String?)
    case home
    case about
    case options
    case help
    case unsupported(String)

    public static func parse(_ rawValue: String) -> EverythingSearchCommand? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return nil
        }

        let lowercased = value.lowercased()
        switch lowercased {
        case "about:", "about:credits", "about:licence", "about:license":
            return .about
        case "about:home":
            return .home
        case "about:options", "about:preferences":
            return .options
        default:
            break
        }

        guard value.hasPrefix("/") else {
            return nil
        }

        let body = value.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else {
            return .unsupported("/")
        }

        let commandEnd = body.firstIndex(where: { $0.isWhitespace }) ?? body.endIndex
        let command = body[..<commandEnd]
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
        let argument = body[commandEnd...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty

        switch command {
        case "close":
            return .close
        case "closeall", "close_all":
            return .closeAll
        case "quit", "exit":
            return .quit
        case "rebuild", "reindex":
            return .rebuild
        case "update":
            return .update(path: argument)
        case "help":
            return .help
        case "monitor_pause", "monitor_resume", "debug", "debug_log", "verbose",
             "config_save", "config_load", "command", "restart":
            return .unsupported(String(command))
        default:
            return .unsupported(String(command))
        }
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
