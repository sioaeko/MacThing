import Foundation

public enum QueryServiceCORSPolicy: String, Codable, CaseIterable, Sendable {
    case disabled
    case loopback
    case custom
}

public struct QueryServiceSettings: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var port: Int
    public var requiresAuthentication: Bool
    public var authenticationToken: String
    public var corsPolicy: QueryServiceCORSPolicy
    public var customAllowedOrigin: String

    public init(
        isEnabled: Bool = true,
        port: Int = 16_245,
        requiresAuthentication: Bool = false,
        authenticationToken: String = "",
        corsPolicy: QueryServiceCORSPolicy = .loopback,
        customAllowedOrigin: String = ""
    ) {
        self.isEnabled = isEnabled
        self.port = port
        self.requiresAuthentication = requiresAuthentication
        self.authenticationToken = authenticationToken
        self.corsPolicy = corsPolicy
        self.customAllowedOrigin = customAllowedOrigin
    }

    public static var defaults: QueryServiceSettings {
        QueryServiceSettings(authenticationToken: generateAuthenticationToken())
    }

    public static func generateAuthenticationToken() -> String {
        var generator = SystemRandomNumberGenerator()
        return (0..<32)
            .map { _ in String(format: "%02x", UInt8.random(in: .min ... .max, using: &generator)) }
            .joined()
    }

    public var validationMessage: String? {
        guard (1_024...65_535).contains(port) else {
            return "Port must be between 1024 and 65535"
        }

        if requiresAuthentication {
            let token = authenticationToken.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty else {
                return "Authentication token is required"
            }
            guard token.unicodeScalars.allSatisfy({ (33...126).contains(Int($0.value)) }) else {
                return "Authentication token must use visible ASCII characters"
            }
        }

        if corsPolicy == .custom,
           QueryHTTPServer.Configuration.normalizedOrigin(customAllowedOrigin) == nil {
            return "Enter one HTTP or HTTPS origin without a path"
        }
        return nil
    }

    public var serverConfiguration: QueryHTTPServer.Configuration? {
        guard validationMessage == nil else {
            return nil
        }

        let token = requiresAuthentication
            ? authenticationToken.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil
        let serverCORSPolicy: QueryHTTPServer.Configuration.CORSPolicy
        switch corsPolicy {
        case .disabled:
            serverCORSPolicy = .disabled
        case .loopback:
            serverCORSPolicy = .loopback
        case .custom:
            serverCORSPolicy = .custom(customAllowedOrigin)
        }
        return QueryHTTPServer.Configuration(
            authorizationToken: token,
            corsPolicy: serverCORSPolicy
        )
    }

    public var endpointURL: URL? {
        guard (1...65_535).contains(port) else {
            return nil
        }
        return URL(string: "http://127.0.0.1:\(port)")
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case port
        case requiresAuthentication
        case authenticationToken
        case corsPolicy
        case customAllowedOrigin
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            isEnabled: try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true,
            port: try container.decodeIfPresent(Int.self, forKey: .port) ?? 16_245,
            requiresAuthentication: try container.decodeIfPresent(Bool.self, forKey: .requiresAuthentication) ?? false,
            authenticationToken: try container.decodeIfPresent(String.self, forKey: .authenticationToken) ?? Self.generateAuthenticationToken(),
            corsPolicy: try container.decodeIfPresent(QueryServiceCORSPolicy.self, forKey: .corsPolicy) ?? .loopback,
            customAllowedOrigin: try container.decodeIfPresent(String.self, forKey: .customAllowedOrigin) ?? ""
        )
    }
}
