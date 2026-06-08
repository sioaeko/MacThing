import Foundation

public enum FileKind: String, Codable, Sendable {
    case file
    case folder
    case package
    case symlink
    case other

    public var displayName: String {
        switch self {
        case .file:
            return "File"
        case .folder:
            return "Folder"
        case .package:
            return "Package"
        case .symlink:
            return "Link"
        case .other:
            return "Other"
        }
    }
}

public struct FileAttributes: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let hidden = FileAttributes(rawValue: 1 << 0)
    public static let readonly = FileAttributes(rawValue: 1 << 1)
    public static let system = FileAttributes(rawValue: 1 << 2)
    public static let directory = FileAttributes(rawValue: 1 << 3)
    public static let symlink = FileAttributes(rawValue: 1 << 4)
    public static let package = FileAttributes(rawValue: 1 << 5)
    public static let file = FileAttributes(rawValue: 1 << 6)
    public static let archive = FileAttributes(rawValue: 1 << 7)
    public static let compressed = FileAttributes(rawValue: 1 << 8)
    public static let encrypted = FileAttributes(rawValue: 1 << 9)
    public static let notContentIndexed = FileAttributes(rawValue: 1 << 10)
    public static let normal = FileAttributes(rawValue: 1 << 11)
    public static let offline = FileAttributes(rawValue: 1 << 12)
    public static let sparse = FileAttributes(rawValue: 1 << 13)
    public static let temporary = FileAttributes(rawValue: 1 << 14)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(Int.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static func inferred(
        kind: FileKind,
        name: String,
        path: String,
        isHidden: Bool? = nil,
        isWritable: Bool? = nil
    ) -> FileAttributes {
        var attributes: FileAttributes = []

        switch kind {
        case .file:
            attributes.insert(.file)
        case .folder:
            attributes.insert(.directory)
        case .package:
            attributes.insert([.directory, .package])
        case .symlink:
            attributes.insert(.symlink)
        case .other:
            break
        }

        if isHidden == true || name.hasPrefix(".") {
            attributes.insert(.hidden)
        }

        if isWritable == false {
            attributes.insert(.readonly)
        }

        if path == "/System" ||
            path.hasPrefix("/System/") ||
            path == "/Library" ||
            path.hasPrefix("/Library/") ||
            path == "/bin" ||
            path.hasPrefix("/bin/") ||
            path == "/sbin" ||
            path.hasPrefix("/sbin/") ||
            path == "/usr" ||
            path.hasPrefix("/usr/") {
            attributes.insert(.system)
        }

        return attributes
    }

    public static func parseEFUAttributes(_ value: String) -> FileAttributes {
        var attributes: FileAttributes = []
        for character in value.uppercased() {
            switch character {
            case "A":
                attributes.insert(.archive)
            case "C":
                attributes.insert(.compressed)
            case "D":
                attributes.insert(.directory)
            case "E":
                attributes.insert(.encrypted)
            case "H":
                attributes.insert(.hidden)
            case "I":
                attributes.insert(.notContentIndexed)
            case "L":
                attributes.insert(.symlink)
            case "N":
                attributes.insert(.normal)
            case "O":
                attributes.insert(.offline)
            case "P":
                attributes.insert(.sparse)
            case "R":
                attributes.insert(.readonly)
            case "S":
                attributes.insert(.system)
            case "T":
                attributes.insert(.temporary)
            default:
                continue
            }
        }
        return attributes
    }
}

public struct FileEntry: Codable, Hashable, Identifiable, Sendable {
    public var id: String { path }

    public let path: String
    public let name: String
    public let parent: String
    public let kind: FileKind
    public let byteSize: Int64?
    public let createdAt: Date?
    public let modifiedAt: Date?
    public let accessedAt: Date?
    public let indexedAt: Date
    public let runCount: Int?
    public let lastRunAt: Date?
    public let attributes: FileAttributes
    public let fileID: String?
    public let volumeID: String?
    public let fileListName: String?
    public let fileListPath: String?
    public let mediaTitle: String?
    public let mediaArtist: String?
    public let mediaAlbum: String?
    public let mediaComment: String?
    public let mediaGenre: String?
    public let mediaTrack: Int?
    public let mediaYear: Int?

    public init(
        path: String,
        name: String,
        parent: String,
        kind: FileKind,
        byteSize: Int64?,
        createdAt: Date? = nil,
        modifiedAt: Date?,
        accessedAt: Date? = nil,
        indexedAt: Date = Date(),
        runCount: Int? = nil,
        lastRunAt: Date? = nil,
        attributes: FileAttributes? = nil,
        fileID: String? = nil,
        volumeID: String? = nil,
        fileListName: String? = nil,
        fileListPath: String? = nil,
        mediaTitle: String? = nil,
        mediaArtist: String? = nil,
        mediaAlbum: String? = nil,
        mediaComment: String? = nil,
        mediaGenre: String? = nil,
        mediaTrack: Int? = nil,
        mediaYear: Int? = nil
    ) {
        self.path = path
        self.name = name
        self.parent = parent
        self.kind = kind
        self.byteSize = byteSize
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.accessedAt = accessedAt
        self.indexedAt = indexedAt
        self.runCount = runCount
        self.lastRunAt = lastRunAt
        self.attributes = attributes ?? FileAttributes.inferred(kind: kind, name: name, path: path)
        self.fileID = fileID
        self.volumeID = volumeID
        self.fileListName = fileListName
        self.fileListPath = fileListPath
        self.mediaTitle = mediaTitle
        self.mediaArtist = mediaArtist
        self.mediaAlbum = mediaAlbum
        self.mediaComment = mediaComment
        self.mediaGenre = mediaGenre
        self.mediaTrack = mediaTrack
        self.mediaYear = mediaYear
    }

    public var extensionName: String {
        URL(fileURLWithPath: path).pathExtension
    }

    public var namePart: String {
        let extensionName = URL(fileURLWithPath: name).pathExtension
        guard !extensionName.isEmpty,
              name.count > extensionName.count + 1 else {
            return name
        }
        return String(name.dropLast(extensionName.count + 1))
    }

    public var depth: Int {
        guard !parent.isEmpty, parent != "/" else {
            return 0
        }
        return parent.split(separator: "/").count
    }

    public var runCountValue: Int {
        runCount ?? 0
    }

    public var identityKey: String? {
        guard let fileID, let volumeID, !fileID.isEmpty, !volumeID.isEmpty else {
            return nil
        }
        return "\(volumeID):\(fileID)"
    }

    public func preservingRunState(from previousEntry: FileEntry) -> FileEntry {
        FileEntry(
            path: path,
            name: name,
            parent: parent,
            kind: kind,
            byteSize: byteSize,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            accessedAt: accessedAt,
            indexedAt: indexedAt,
            runCount: previousEntry.runCount,
            lastRunAt: previousEntry.lastRunAt,
            attributes: attributes,
            fileID: fileID,
            volumeID: volumeID,
            fileListName: fileListName,
            fileListPath: fileListPath,
            mediaTitle: mediaTitle,
            mediaArtist: mediaArtist,
            mediaAlbum: mediaAlbum,
            mediaComment: mediaComment,
            mediaGenre: mediaGenre,
            mediaTrack: mediaTrack,
            mediaYear: mediaYear
        )
    }

    public func recordingRun(at date: Date = Date()) -> FileEntry {
        FileEntry(
            path: path,
            name: name,
            parent: parent,
            kind: kind,
            byteSize: byteSize,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            accessedAt: accessedAt,
            indexedAt: indexedAt,
            runCount: runCountValue + 1,
            lastRunAt: date,
            attributes: attributes,
            fileID: fileID,
            volumeID: volumeID,
            fileListName: fileListName,
            fileListPath: fileListPath,
            mediaTitle: mediaTitle,
            mediaArtist: mediaArtist,
            mediaAlbum: mediaAlbum,
            mediaComment: mediaComment,
            mediaGenre: mediaGenre,
            mediaTrack: mediaTrack,
            mediaYear: mediaYear
        )
    }

    public func markingFileListSource(name: String, path: String) -> FileEntry {
        FileEntry(
            path: self.path,
            name: self.name,
            parent: parent,
            kind: kind,
            byteSize: byteSize,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            accessedAt: accessedAt,
            indexedAt: indexedAt,
            runCount: runCount,
            lastRunAt: lastRunAt,
            attributes: attributes,
            fileID: fileID,
            volumeID: volumeID,
            fileListName: name,
            fileListPath: path,
            mediaTitle: mediaTitle,
            mediaArtist: mediaArtist,
            mediaAlbum: mediaAlbum,
            mediaComment: mediaComment,
            mediaGenre: mediaGenre,
            mediaTrack: mediaTrack,
            mediaYear: mediaYear
        )
    }
}
