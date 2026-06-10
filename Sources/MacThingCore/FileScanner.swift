import Darwin
import CoreServices
import Foundation

public struct ScanConfiguration: Sendable {
    public let rootURL: URL
    public let includeHiddenFiles: Bool
    public let skippedDirectoryNames: Set<String>
    public let excludedPathPrefixes: [String]
    public let excludedNamePatterns: [String]
    public let excludedExtensions: Set<String>

    public init(
        rootURL: URL,
        includeHiddenFiles: Bool = true,
        skippedDirectoryNames: Set<String> = FileScanner.defaultSkippedDirectoryNames,
        excludedPathPrefixes: [String] = [],
        excludedNamePatterns: [String] = [],
        excludedExtensions: Set<String> = []
    ) {
        self.rootURL = rootURL
        self.includeHiddenFiles = includeHiddenFiles
        self.skippedDirectoryNames = skippedDirectoryNames
        self.excludedPathPrefixes = excludedPathPrefixes.compactMap(IndexExclusionRules.normalizedPathPrefix(for:))
        self.excludedNamePatterns = excludedNamePatterns.compactMap(IndexExclusionRules.normalizedNamePattern)
        self.excludedExtensions = Set(excludedExtensions.compactMap(IndexExclusionRules.normalizedExtension))
    }

    public init(
        rootURL: URL,
        exclusionRules: IndexExclusionRules,
        runtimeExcludedPathPrefixes: [String] = [],
        skippedDirectoryNames: Set<String> = FileScanner.defaultSkippedDirectoryNames
    ) {
        let normalizedRules = exclusionRules.normalized()
        self.init(
            rootURL: rootURL,
            includeHiddenFiles: normalizedRules.includeHiddenFiles,
            skippedDirectoryNames: skippedDirectoryNames,
            excludedPathPrefixes: normalizedRules.excludedPathPrefixes + runtimeExcludedPathPrefixes,
            excludedNamePatterns: normalizedRules.excludedNamePatterns,
            excludedExtensions: normalizedRules.excludedExtensions
        )
    }
}

public enum FileScanner {
    public static let defaultSkippedDirectoryNames: Set<String> = [
        ".Trash",
        ".DocumentRevisions-V100",
        ".Spotlight-V100",
        ".TemporaryItems",
        ".fseventsd",
        ".build",
        ".dart_tool",
        ".git",
        ".gradle",
        ".hg",
        ".swiftpm",
        ".svn",
        "__pycache__",
        "Caches",
        "DerivedData",
        "node_modules"
    ]

    private struct MediaMetadata {
        var title: String?
        var artist: String?
        var album: String?
        var comment: String?
        var genre: String?
        var track: Int?
        var year: Int?
    }

    private static let mediaMetadataExtensions: Set<String> = [
        "3g2", "3gp", "aac", "aif", "aifc", "aiff", "alac", "avi", "caf",
        "flac", "flv", "m4a", "m4b", "m4p", "m4v", "mkv", "mov", "mp3",
        "mp4", "mpeg", "mpg", "oga", "ogg", "opus", "wav", "wave", "webm",
        "wma", "wmv"
    ]

    public static func scan(configuration: ScanConfiguration) -> [FileEntry] {
        scan(configuration: configuration, existingEntriesByPath: [:])
    }

    public static func scan(
        configuration: ScanConfiguration,
        existingEntriesByPath: [String: FileEntry]
    ) -> [FileEntry] {
        let fileManager = FileManager.default
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .isPackageKey,
            .isHiddenKey,
            .isWritableKey,
            .fileSizeKey,
            .creationDateKey,
            .contentAccessDateKey,
            .contentModificationDateKey
        ]

        var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        if !configuration.includeHiddenFiles {
            options.insert(.skipsHiddenFiles)
        }

        guard let enumerator = fileManager.enumerator(
            at: configuration.rootURL,
            includingPropertiesForKeys: Array(keys),
            options: options,
            errorHandler: { _, _ in true }
        ) else {
            return []
        }

        var entries: [FileEntry] = []
        entries.reserveCapacity(50_000)

        for case let url as URL in enumerator {
            autoreleasepool {
                if isExcludedByPath(url: url, prefixes: configuration.excludedPathPrefixes) {
                    enumerator.skipDescendants()
                    return
                }

                guard let values = try? url.resourceValues(forKeys: keys) else {
                    return
                }

                let kind = kindForResource(values)
                if shouldExclude(url: url, kind: kind, values: values, configuration: configuration) {
                    if kind == .folder || kind == .package {
                        enumerator.skipDescendants()
                    }
                    return
                }

                entries.append(
                    makeEntry(
                        url: url,
                        kind: kind,
                        values: values,
                        previousEntry: existingEntriesByPath[url.path]
                    )
                )
            }
        }

        return entries
    }

    public static func scanChangedPath(
        path: String,
        existingEntriesByPath: [String: FileEntry],
        includeHiddenFiles: Bool = true,
        skippedDirectoryNames: Set<String> = defaultSkippedDirectoryNames,
        excludedPathPrefixes: [String] = [],
        excludedNamePatterns: [String] = [],
        excludedExtensions: Set<String> = []
    ) -> [FileEntry] {
        let url = canonicalURL(forPath: path)
        let configuration = ScanConfiguration(
            rootURL: url,
            includeHiddenFiles: includeHiddenFiles,
            skippedDirectoryNames: skippedDirectoryNames,
            excludedPathPrefixes: excludedPathPrefixes,
            excludedNamePatterns: excludedNamePatterns,
            excludedExtensions: excludedExtensions
        )
        guard !isExcludedByPath(url: url, prefixes: configuration.excludedPathPrefixes),
              !isUnderSkippedDirectory(url: url, configuration: configuration),
              FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        var entries: [FileEntry] = []
        guard let rootEntry = entry(for: url, previousEntry: existingEntriesByPath[url.path]),
              !isExcluded(entry: rootEntry, configuration: configuration) else {
            return []
        }
        entries.append(rootEntry)

        if entries.first?.kind == .folder {
            entries.append(contentsOf: scan(configuration: configuration, existingEntriesByPath: existingEntriesByPath))
        }

        return entries
    }

    public static func scanChangedPath(
        path: String,
        existingEntriesByPath: [String: FileEntry],
        exclusionRules: IndexExclusionRules,
        runtimeExcludedPathPrefixes: [String] = [],
        skippedDirectoryNames: Set<String> = defaultSkippedDirectoryNames
    ) -> [FileEntry] {
        let normalizedRules = exclusionRules.normalized()
        return scanChangedPath(
            path: path,
            existingEntriesByPath: existingEntriesByPath,
            includeHiddenFiles: normalizedRules.includeHiddenFiles,
            skippedDirectoryNames: skippedDirectoryNames,
            excludedPathPrefixes: normalizedRules.excludedPathPrefixes + runtimeExcludedPathPrefixes,
            excludedNamePatterns: normalizedRules.excludedNamePatterns,
            excludedExtensions: normalizedRules.excludedExtensions
        )
    }

    private static func makeEntry(
        url: URL,
        kind: FileKind,
        values: URLResourceValues,
        previousEntry: FileEntry?
    ) -> FileEntry {
        let identity = fileIdentity(forPath: url.path)
        let mediaMetadata = mediaMetadata(for: url, kind: kind)
        return FileEntry(
            path: url.path,
            name: url.lastPathComponent,
            parent: url.deletingLastPathComponent().path,
            kind: kind,
            byteSize: values.fileSize.map(Int64.init),
            createdAt: values.creationDate,
            modifiedAt: values.contentModificationDate,
            accessedAt: values.contentAccessDate,
            runCount: previousEntry?.runCount,
            lastRunAt: previousEntry?.lastRunAt,
            attributes: FileAttributes.inferred(
                kind: kind,
                name: url.lastPathComponent,
                path: url.path,
                isHidden: values.isHidden,
                isWritable: values.isWritable
            ),
            fileID: identity.fileID,
            volumeID: identity.volumeID,
            mediaTitle: mediaMetadata.title,
            mediaArtist: mediaMetadata.artist,
            mediaAlbum: mediaMetadata.album,
            mediaComment: mediaMetadata.comment,
            mediaGenre: mediaMetadata.genre,
            mediaTrack: mediaMetadata.track,
            mediaYear: mediaMetadata.year
        )
    }

    private static func mediaMetadata(for url: URL, kind: FileKind) -> MediaMetadata {
        guard kind == .file,
              mediaMetadataExtensions.contains(url.pathExtension.lowercased()),
              let item = MDItemCreateWithURL(nil, url as CFURL) else {
            return MediaMetadata()
        }

        let recordingYear = intMetadataValue(MDItemCopyAttribute(item, kMDItemRecordingYear))
        let recordingDate = dateMetadataValue(MDItemCopyAttribute(item, kMDItemRecordingDate))
        let calendarYear = recordingDate.map { Calendar(identifier: .gregorian).component(.year, from: $0) }

        return MediaMetadata(
            title: stringMetadataValue(MDItemCopyAttribute(item, kMDItemTitle)),
            artist: firstNonEmpty([
                stringMetadataValue(MDItemCopyAttribute(item, kMDItemPerformers)),
                stringMetadataValue(MDItemCopyAttribute(item, kMDItemAuthors))
            ]),
            album: stringMetadataValue(MDItemCopyAttribute(item, kMDItemAlbum)),
            comment: stringMetadataValue(MDItemCopyAttribute(item, kMDItemComment)),
            genre: stringMetadataValue(MDItemCopyAttribute(item, kMDItemMusicalGenre)),
            track: intMetadataValue(MDItemCopyAttribute(item, kMDItemAudioTrackNumber)),
            year: recordingYear ?? calendarYear
        )
    }

    private static func stringMetadataValue(_ value: CFTypeRef?) -> String? {
        if let string = value as? String {
            return cleanedMetadataString(string)
        }
        if let number = value as? NSNumber {
            return cleanedMetadataString(number.stringValue)
        }
        if let strings = value as? [String] {
            return cleanedMetadataString(strings.joined(separator: "; "))
        }
        if let values = value as? [Any] {
            let strings = values.compactMap { element -> String? in
                if let string = element as? String {
                    return cleanedMetadataString(string)
                }
                if let number = element as? NSNumber {
                    return cleanedMetadataString(number.stringValue)
                }
                return nil
            }
            return cleanedMetadataString(strings.joined(separator: "; "))
        }
        return nil
    }

    private static func intMetadataValue(_ value: CFTypeRef?) -> Int? {
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let string = value as? String {
            return Int(string.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    private static func dateMetadataValue(_ value: CFTypeRef?) -> Date? {
        if let date = value as? Date {
            return date
        }
        return nil
    }

    private static func firstNonEmpty(_ values: [String?]) -> String? {
        values.lazy.compactMap { $0 }.first
    }

    private static func cleanedMetadataString(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func fileIdentity(forPath path: String) -> (fileID: String?, volumeID: String?) {
        var info = stat()
        guard lstat(path, &info) == 0 else {
            return (nil, nil)
        }
        return (String(info.st_ino), String(info.st_dev))
    }

    private static func entry(for url: URL, previousEntry: FileEntry?) -> FileEntry? {
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .isPackageKey,
            .isHiddenKey,
            .isWritableKey,
            .fileSizeKey,
            .creationDateKey,
            .contentAccessDateKey,
            .contentModificationDateKey
        ]

        guard let values = try? url.resourceValues(forKeys: keys) else {
            return nil
        }

        return makeEntry(
            url: url,
            kind: kindForResource(values),
            values: values,
            previousEntry: previousEntry
        )
    }

    private static func kindForResource(_ values: URLResourceValues) -> FileKind {
        if values.isSymbolicLink == true {
            return .symlink
        }

        if values.isPackage == true {
            return .package
        }

        if values.isDirectory == true {
            return .folder
        }

        if values.isRegularFile == true {
            return .file
        }

        return .other
    }

    private static func shouldExclude(
        url: URL,
        kind: FileKind,
        values: URLResourceValues,
        configuration: ScanConfiguration
    ) -> Bool {
        let name = url.lastPathComponent
        if !configuration.includeHiddenFiles, values.isHidden == true {
            return true
        }
        if kind == .folder || kind == .package, configuration.skippedDirectoryNames.contains(name) {
            return true
        }
        if matchesAnyNamePattern(name, patterns: configuration.excludedNamePatterns) {
            return true
        }
        if kind != .folder,
           let extensionName = IndexExclusionRules.normalizedExtension(url.pathExtension),
           configuration.excludedExtensions.contains(extensionName) {
            return true
        }
        return false
    }

    private static func isExcluded(entry: FileEntry, configuration: ScanConfiguration) -> Bool {
        if isExcludedByPath(url: URL(fileURLWithPath: entry.path), prefixes: configuration.excludedPathPrefixes) {
            return true
        }
        if !configuration.includeHiddenFiles, entry.attributes.contains(.hidden) {
            return true
        }
        if entry.kind == .folder || entry.kind == .package,
           configuration.skippedDirectoryNames.contains(entry.name) {
            return true
        }
        if matchesAnyNamePattern(entry.name, patterns: configuration.excludedNamePatterns) {
            return true
        }
        if entry.kind != .folder,
           let extensionName = IndexExclusionRules.normalizedExtension(entry.extensionName),
           configuration.excludedExtensions.contains(extensionName) {
            return true
        }
        return false
    }

    private static func isExcludedByPath(url: URL, prefixes: [String]) -> Bool {
        guard !prefixes.isEmpty else {
            return false
        }

        let path = url.path
        let resolvedPath = url.resolvingSymlinksInPath().standardizedFileURL.path
        return prefixes.contains { prefix in
            path == prefix ||
                path.hasPrefix(prefix + "/") ||
                resolvedPath == prefix ||
                resolvedPath.hasPrefix(prefix + "/")
        }
    }

    private static func isUnderSkippedDirectory(url: URL, configuration: ScanConfiguration) -> Bool {
        url
            .standardizedFileURL
            .pathComponents
            .contains { configuration.skippedDirectoryNames.contains($0) }
    }

    private static func matchesAnyNamePattern(_ name: String, patterns: [String]) -> Bool {
        patterns.contains { pattern in
            matchesWildcard(pattern: pattern, candidate: name)
        }
    }

    private static func matchesWildcard(pattern: String, candidate: String) -> Bool {
        let regex = "^" + NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*", with: ".*")
            .replacingOccurrences(of: "\\?", with: ".") + "$"
        return candidate.range(of: regex, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func canonicalURL(forPath path: String) -> URL {
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        if realpath(path, &buffer) != nil {
            let resolvedPath = buffer.withUnsafeBufferPointer { pointer in
                String(cString: pointer.baseAddress!)
            }
            return URL(fileURLWithPath: resolvedPath)
        }
        return URL(fileURLWithPath: path)
    }
}
