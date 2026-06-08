import Foundation

public struct IndexExclusionRules: Codable, Hashable, Sendable {
    public var includeHiddenFiles: Bool
    public var excludedPathPrefixes: [String]
    public var excludedNamePatterns: [String]
    public var excludedExtensions: Set<String>

    public init(
        includeHiddenFiles: Bool = true,
        excludedPathPrefixes: [String] = [],
        excludedNamePatterns: [String] = [],
        excludedExtensions: Set<String> = []
    ) {
        self.includeHiddenFiles = includeHiddenFiles
        self.excludedPathPrefixes = Self.normalizedPathPrefixes(excludedPathPrefixes)
        self.excludedNamePatterns = Self.normalizedNamePatterns(excludedNamePatterns)
        self.excludedExtensions = Self.normalizedExtensions(excludedExtensions)
    }

    public var hasCustomRules: Bool {
        !includeHiddenFiles ||
            !excludedPathPrefixes.isEmpty ||
            !excludedNamePatterns.isEmpty ||
            !excludedExtensions.isEmpty
    }

    public func normalized() -> IndexExclusionRules {
        IndexExclusionRules(
            includeHiddenFiles: includeHiddenFiles,
            excludedPathPrefixes: excludedPathPrefixes,
            excludedNamePatterns: excludedNamePatterns,
            excludedExtensions: excludedExtensions
        )
    }

    public static func normalizedPathPrefix(for path: String) -> String? {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: trimmedPath)
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
    }

    public static func normalizedExtension(_ value: String) -> String? {
        var trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmedValue.hasPrefix(".") {
            trimmedValue.removeFirst()
        }
        let normalizedValue = trimmedValue.lowercased()
        return normalizedValue.isEmpty ? nil : normalizedValue
    }

    public static func normalizedNamePattern(_ value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private enum CodingKeys: String, CodingKey {
        case includeHiddenFiles
        case excludedPathPrefixes
        case excludedNamePatterns
        case excludedExtensions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            includeHiddenFiles: try container.decodeIfPresent(Bool.self, forKey: .includeHiddenFiles) ?? true,
            excludedPathPrefixes: try container.decodeIfPresent([String].self, forKey: .excludedPathPrefixes) ?? [],
            excludedNamePatterns: try container.decodeIfPresent([String].self, forKey: .excludedNamePatterns) ?? [],
            excludedExtensions: try container.decodeIfPresent(Set<String>.self, forKey: .excludedExtensions) ?? []
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(includeHiddenFiles, forKey: .includeHiddenFiles)
        try container.encode(excludedPathPrefixes, forKey: .excludedPathPrefixes)
        try container.encode(excludedNamePatterns, forKey: .excludedNamePatterns)
        try container.encode(excludedExtensions, forKey: .excludedExtensions)
    }

    private static func normalizedPathPrefixes(_ values: [String]) -> [String] {
        stableUnique(values.compactMap(normalizedPathPrefix(for:)), key: { $0 })
    }

    private static func normalizedNamePatterns(_ values: [String]) -> [String] {
        stableUnique(values.compactMap(normalizedNamePattern), key: { $0.lowercased() })
    }

    private static func normalizedExtensions(_ values: Set<String>) -> Set<String> {
        Set(values.compactMap(normalizedExtension))
    }

    private static func stableUnique<T>(_ values: [T], key: (T) -> String) -> [T] {
        var seen = Set<String>()
        var result: [T] = []
        for value in values {
            let key = key(value)
            guard !seen.contains(key) else {
                continue
            }
            seen.insert(key)
            result.append(value)
        }
        return result
    }
}

public struct IndexProfile: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public var name: String
    public var rootPath: String
    public var createdAt: Date
    public var updatedAt: Date
    public var lastFSEventID: UInt64?
    public var exclusionRules: IndexExclusionRules
    public var isEnabled: Bool

    public init(
        id: String,
        name: String,
        rootPath: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastFSEventID: UInt64? = nil,
        exclusionRules: IndexExclusionRules = IndexExclusionRules(),
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.rootPath = rootPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastFSEventID = lastFSEventID
        self.exclusionRules = exclusionRules.normalized()
        self.isEnabled = isEnabled
    }

    public var displayName: String {
        name.isEmpty ? rootPath : name
    }

    public static func make(rootPath: String, name: String? = nil, date: Date = Date()) -> IndexProfile {
        let normalizedPath = URL(fileURLWithPath: rootPath).standardizedFileURL.path
        let profileName = name ?? URL(fileURLWithPath: normalizedPath).lastPathComponent.nonEmpty ?? normalizedPath
        return IndexProfile(
            id: stableID(for: normalizedPath),
            name: profileName,
            rootPath: normalizedPath,
            createdAt: date,
            updatedAt: date
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case rootPath
        case createdAt
        case updatedAt
        case lastFSEventID
        case exclusionRules
        case isEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            rootPath: try container.decode(String.self, forKey: .rootPath),
            createdAt: try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(),
            updatedAt: try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date(),
            lastFSEventID: try container.decodeIfPresent(UInt64.self, forKey: .lastFSEventID),
            exclusionRules: try container.decodeIfPresent(IndexExclusionRules.self, forKey: .exclusionRules) ?? IndexExclusionRules(),
            isEnabled: try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(rootPath, forKey: .rootPath)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(lastFSEventID, forKey: .lastFSEventID)
        try container.encode(exclusionRules, forKey: .exclusionRules)
        try container.encode(isEnabled, forKey: .isEnabled)
    }

    private static func stableID(for value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
