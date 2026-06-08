import Foundation

public enum ResultExportColumn: String, CaseIterable, Codable, Sendable {
    case name
    case path
    case parent
    case extensionName = "extension"
    case kind
    case size
    case dateModified
    case dateCreated
    case dateAccessed
    case dateIndexed
    case runCount
    case dateRun
    case attributes
    case fileID
    case volumeID
    case title
    case artist
    case album
    case comment
    case genre
    case track
    case year

    public var displayName: String {
        switch self {
        case .name:
            return "Name"
        case .path:
            return "Path"
        case .parent:
            return "Parent"
        case .extensionName:
            return "Extension"
        case .kind:
            return "Kind"
        case .size:
            return "Size"
        case .dateModified:
            return "Date Modified"
        case .dateCreated:
            return "Date Created"
        case .dateAccessed:
            return "Date Accessed"
        case .dateIndexed:
            return "Date Indexed"
        case .runCount:
            return "Run Count"
        case .dateRun:
            return "Date Run"
        case .attributes:
            return "Attributes"
        case .fileID:
            return "File ID"
        case .volumeID:
            return "Volume ID"
        case .title:
            return "Title"
        case .artist:
            return "Artist"
        case .album:
            return "Album"
        case .comment:
            return "Comment"
        case .genre:
            return "Genre"
        case .track:
            return "Track"
        case .year:
            return "Year"
        }
    }

    public static let defaults: [ResultExportColumn] = [
        .name,
        .path,
        .extensionName,
        .kind,
        .size,
        .dateModified,
        .dateCreated,
        .dateAccessed,
        .runCount,
        .attributes
    ]

    public static func parseList(_ value: String?) -> [ResultExportColumn] {
        guard let value, !value.isEmpty else {
            return defaults
        }

        let parsed = value
            .split(separator: ",")
            .compactMap { ResultExportColumn(rawValue: String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }

        return parsed.isEmpty ? defaults : parsed
    }

    func stringValue(for entry: FileEntry) -> String {
        switch self {
        case .name:
            return entry.name
        case .path:
            return entry.path
        case .parent:
            return entry.parent
        case .extensionName:
            return entry.extensionName
        case .kind:
            return entry.kind.displayName
        case .size:
            return entry.byteSize.map(String.init) ?? ""
        case .dateModified:
            return entry.modifiedAt.map(ResultExporter.formatDate) ?? ""
        case .dateCreated:
            return entry.createdAt.map(ResultExporter.formatDate) ?? ""
        case .dateAccessed:
            return entry.accessedAt.map(ResultExporter.formatDate) ?? ""
        case .dateIndexed:
            return ResultExporter.formatDate(entry.indexedAt)
        case .runCount:
            return String(entry.runCountValue)
        case .dateRun:
            return entry.lastRunAt.map(ResultExporter.formatDate) ?? ""
        case .attributes:
            return ResultExporter.attributeString(for: entry)
        case .fileID:
            return entry.fileID ?? ""
        case .volumeID:
            return entry.volumeID ?? ""
        case .title:
            return entry.mediaTitle ?? ""
        case .artist:
            return entry.mediaArtist ?? ""
        case .album:
            return entry.mediaAlbum ?? ""
        case .comment:
            return entry.mediaComment ?? ""
        case .genre:
            return entry.mediaGenre ?? ""
        case .track:
            return entry.mediaTrack.map(String.init) ?? ""
        case .year:
            return entry.mediaYear.map(String.init) ?? ""
        }
    }
}

public enum ResultExporter {
    public static func csv(
        entries: [FileEntry],
        columns: [ResultExportColumn] = ResultExportColumn.defaults
    ) -> String {
        var rows = [
            columns.map(\.displayName)
        ]

        rows.append(contentsOf: entries.map { entry in
            columns.map { $0.stringValue(for: entry) }
        })

        return rows
            .map { $0.map(escapeCSV).joined(separator: ",") }
            .joined(separator: "\n") + "\n"
    }

    public static func text(entries: [FileEntry]) -> String {
        entries.map(\.path).joined(separator: "\n") + "\n"
    }

    public static func efu(entries: [FileEntry]) -> String {
        var rows = [
            ["Filename", "Size", "Date Modified", "Date Created", "Attributes"]
        ]

        rows.append(contentsOf: entries.map { entry in
            [
                entry.path,
                entry.byteSize.map(String.init) ?? "",
                entry.modifiedAt.map(formatDate) ?? "",
                entry.createdAt.map(formatDate) ?? "",
                attributeString(for: entry)
            ]
        })

        return rows
            .map { $0.map(escapeCSV).joined(separator: ",") }
            .joined(separator: "\n") + "\n"
    }

    public static func rows(
        entries: [FileEntry],
        columns: [ResultExportColumn]
    ) -> [[String: String]] {
        entries.map { entry in
            Dictionary(uniqueKeysWithValues: columns.map { column in
                (column.rawValue, column.stringValue(for: entry))
            })
        }
    }

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    static func formatDate(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    public static func attributeString(for entry: FileEntry) -> String {
        let attributes = entry.attributes
        var value = ""
        if attributes.contains(.archive) {
            value.append("A")
        }
        if attributes.contains(.compressed) {
            value.append("C")
        }
        if attributes.contains(.directory) || entry.kind == .folder {
            value.append("D")
        }
        if attributes.contains(.encrypted) {
            value.append("E")
        }
        if attributes.contains(.hidden) {
            value.append("H")
        }
        if attributes.contains(.notContentIndexed) {
            value.append("I")
        }
        if attributes.contains(.symlink) || entry.kind == .symlink {
            value.append("L")
        }
        if attributes.contains(.normal) {
            value.append("N")
        }
        if attributes.contains(.offline) {
            value.append("O")
        }
        if attributes.contains(.sparse) {
            value.append("P")
        }
        if attributes.contains(.readonly) {
            value.append("R")
        }
        if attributes.contains(.system) {
            value.append("S")
        }
        if attributes.contains(.temporary) {
            value.append("T")
        }
        return value
    }
}
