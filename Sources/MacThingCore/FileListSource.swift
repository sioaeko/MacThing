import Foundation

public struct FileListSource: Codable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var originalPath: String
    public var isEnabled: Bool
    public var importedAt: Date
    public var updatedAt: Date
    public var entries: [FileEntry]

    public init(
        id: UUID = UUID(),
        name: String,
        originalPath: String,
        isEnabled: Bool = true,
        importedAt: Date = Date(),
        updatedAt: Date = Date(),
        entries: [FileEntry]
    ) {
        self.id = id
        self.name = name
        self.originalPath = originalPath
        self.isEnabled = isEnabled
        self.importedAt = importedAt
        self.updatedAt = updatedAt
        self.entries = entries
    }

    public var displayName: String {
        name.isEmpty ? URL(fileURLWithPath: originalPath).lastPathComponent : name
    }

    public var itemCount: Int {
        entries.count
    }

    public var entriesWithSourceMetadata: [FileEntry] {
        entries.map {
            $0.markingFileListSource(name: displayName, path: originalPath)
        }
    }
}

public enum FileListSourceStorage {
    public static func defaultURL() throws -> URL {
        try IndexStorage.applicationSupportDirectory().appending(path: "FileLists.json")
    }

    public static func load(from url: URL) throws -> [FileListSource] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([FileListSource].self, from: data)
    }

    public static func save(_ sources: [FileListSource], to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(sources)
        try data.write(to: url, options: .atomic)
    }
}
