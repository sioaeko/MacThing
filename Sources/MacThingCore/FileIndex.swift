import Foundation

public struct FileIndex: Sendable {
    private var entriesByPath: [String: FileEntry]

    public init(entries: [FileEntry] = []) {
        entriesByPath = Dictionary(uniqueKeysWithValues: entries.map { ($0.path, $0) })
    }

    public var entries: [FileEntry] {
        entriesByPath.values.sorted { lhs, rhs in
            lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
        }
    }

    public var count: Int {
        entriesByPath.count
    }

    public var isEmpty: Bool {
        entriesByPath.isEmpty
    }

    public var snapshotByPath: [String: FileEntry] {
        entriesByPath
    }

    public mutating func replaceAll(_ entries: [FileEntry]) {
        entriesByPath = Dictionary(uniqueKeysWithValues: entries.map { ($0.path, $0) })
    }

    public mutating func upsert(_ entry: FileEntry) {
        entriesByPath[entry.path] = entry
    }

    public mutating func upsert(_ entries: [FileEntry]) {
        for entry in entries {
            upsert(entry)
        }
    }

    @discardableResult
    public mutating func remove(path: String) -> [String] {
        remove(prefixes: [path])
    }

    @discardableResult
    public mutating func remove(prefixes: [String]) -> [String] {
        guard !prefixes.isEmpty else {
            return []
        }

        let removedPaths = entriesByPath.keys.filter { path in
            prefixes.contains { prefix in
                path == prefix || path.hasPrefix(prefix + "/")
            }
        }

        for path in removedPaths {
            entriesByPath.removeValue(forKey: path)
        }

        return removedPaths
    }

    public func entry(path: String) -> FileEntry? {
        entriesByPath[path]
    }
}
