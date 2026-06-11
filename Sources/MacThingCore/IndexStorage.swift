import Foundation

public enum IndexStorageError: Error {
    case sqlite(String)
}

public struct IndexSnapshot: Codable, Sendable {
    public let rootPath: String
    public let createdAt: Date
    public let entries: [FileEntry]

    public init(rootPath: String, createdAt: Date = Date(), entries: [FileEntry]) {
        self.rootPath = rootPath
        self.createdAt = createdAt
        self.entries = entries
    }
}

public enum IndexStorage {
    public static func applicationSupportDirectory() throws -> URL {
        let supportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = supportURL.appending(path: "MacThing", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    public static func defaultIndexURL() throws -> URL {
        let directory = try applicationSupportDirectory()
        return directory.appending(path: "MacThing.db")
    }

    public static func profileIndexURL(profileID: String) throws -> URL {
        try profileIndexURL(profileID: profileID, applicationDirectory: applicationSupportDirectory())
    }

    public static func profileIndexURL(profileID: String, applicationDirectory: URL) throws -> URL {
        let directory = applicationDirectory
            .appending(path: "Profiles", directoryHint: .isDirectory)
            .appending(path: profileID, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "MacThing.db")
    }

    public static func load(from url: URL) throws -> IndexSnapshot {
        try SQLiteIndexStorage.load(from: url)
    }

    public static func save(_ snapshot: IndexSnapshot, to url: URL) throws {
        try SQLiteIndexStorage.replace(snapshot, to: url)
    }

    public static func upsert(entries: [FileEntry], rootPath: String, to url: URL) throws {
        try SQLiteIndexStorage.upsert(entries: entries, rootPath: rootPath, to: url)
    }

    public static func delete(paths: [String], rootPath: String, from url: URL) throws {
        try SQLiteIndexStorage.delete(paths: paths, rootPath: rootPath, from: url)
    }

    public static func candidateEntries(terms: [String], limit: Int, from url: URL) throws -> [FileEntry] {
        try SQLiteIndexStorage.candidateEntries(terms: terms, limit: limit, from: url)
    }

    public static func candidateEntries(hint: SearchCandidateHint, limit: Int, from url: URL) throws -> [FileEntry] {
        try SQLiteIndexStorage.candidateEntries(hint: hint, limit: limit, from: url)
    }

    public static func windowEntries(limit: Int, offset: Int, from url: URL) throws -> [FileEntry] {
        try SQLiteIndexStorage.windowEntries(limit: limit, offset: offset, from: url)
    }

    public static func entryCount(from url: URL) throws -> Int {
        try SQLiteIndexStorage.entryCount(from: url)
    }
}
