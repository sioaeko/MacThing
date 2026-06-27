import Foundation
import Darwin
import MacThingCore

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Self-test failed: \(message)\n", stderr)
        exit(1)
    }
}

func canonicalPath(_ path: String) -> String {
    var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
    if realpath(path, &buffer) != nil {
        return buffer.withUnsafeBufferPointer { pointer in
            String(cString: pointer.baseAddress!)
        }
    }
    return path
}

final class HTTPResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Result<String, Error>?

    func set(_ result: Result<String, Error>) {
        lock.lock()
        storage = result
        lock.unlock()
    }

    func get() -> Result<String, Error>? {
        lock.lock()
        let result = storage
        lock.unlock()
        return result
    }
}

let defaultShortcuts = AppShortcutSettings.defaults
expect(
    defaultShortcuts.choice(for: .quickSearch) == .optionSpace &&
        defaultShortcuts.choice(for: .reindex) == .commandShiftR,
    "app shortcuts should keep existing default command mappings"
)
expect(
    AppShortcutAction.quickSearch.defaultChoice == .optionSpace &&
        AppShortcutAction.showWindow.defaultChoice == .command0 &&
        AppShortcutAction.openSelected.defaultChoice == .disabled,
    "shortcut actions should expose their default mapping"
)
expect(
    defaultShortcuts.isDefault(for: .quickSearch) &&
        defaultShortcuts.isDefault(for: .openSelected),
    "default shortcut settings should report default rows"
)

var reassignedShortcuts = defaultShortcuts
let clearedReassignedShortcuts = reassignedShortcuts.set(.commandShiftR, for: .quickSearch)
expect(
    reassignedShortcuts.choice(for: .quickSearch) == .commandShiftR &&
        reassignedShortcuts.choice(for: .reindex) == .disabled &&
        clearedReassignedShortcuts == [.reindex],
    "app shortcut settings should report and clear duplicate command mappings"
)
expect(
    !reassignedShortcuts.isDefault(for: .quickSearch),
    "custom shortcut rows should report non-default mappings"
)

var resetDuplicateShortcuts = AppShortcutSettings.defaults.setting(.command0, for: .quickSearch)
let resetDuplicateClearedActions = resetDuplicateShortcuts.reset(.showWindow)
expect(
    resetDuplicateShortcuts.choice(for: .showWindow) == .command0 &&
        resetDuplicateShortcuts.choice(for: .quickSearch) == .disabled &&
        resetDuplicateShortcuts.isDefault(for: .showWindow) &&
        resetDuplicateClearedActions == [.quickSearch],
    "resetting one shortcut should restore its default and clear duplicate mappings"
)

let customShortcut = AppShortcutChoice(key: .m, modifiers: [.command, .option])
let customShortcutData = try! JSONEncoder().encode(customShortcut)
let decodedCustomShortcut = try! JSONDecoder().decode(AppShortcutChoice.self, from: customShortcutData)
expect(
    decodedCustomShortcut == customShortcut,
    "custom app shortcuts should round-trip through settings storage"
)

let legacyShortcutData = Data("\"commandOptionP\"".utf8)
let decodedLegacyShortcut = try! JSONDecoder().decode(AppShortcutChoice.self, from: legacyShortcutData)
expect(
    decodedLegacyShortcut == .commandOptionP,
    "app shortcuts should decode legacy preset storage names"
)

let reassignedCustomShortcuts = AppShortcutSettings.defaults
    .setting(customShortcut, for: .toggleFuzzyMatching)
    .setting(customShortcut, for: .toggleCaseSensitive)
expect(
    reassignedCustomShortcuts.choice(for: .toggleFuzzyMatching) == .disabled &&
        reassignedCustomShortcuts.choice(for: .toggleCaseSensitive) == customShortcut,
    "custom app shortcut settings should clear duplicate command mappings"
)

let reassignedSearchOptionShortcuts = AppShortcutSettings.defaults
    .setting(.commandOptionX, for: .toggleRegexMatching)
    .setting(.commandOptionX, for: .toggleWholeWordMatching)
expect(
    reassignedSearchOptionShortcuts.choice(for: .toggleRegexMatching) == .disabled &&
        reassignedSearchOptionShortcuts.choice(for: .toggleWholeWordMatching) == .commandOptionX,
    "search option shortcut settings should clear duplicate command mappings"
)

let reassignedResultActionShortcuts = AppShortcutSettings.defaults
    .setting(.commandOptionC, for: .copySelectedPath)
    .setting(.commandOptionC, for: .toggleCaseSensitive)
expect(
    reassignedResultActionShortcuts.choice(for: .copySelectedPath) == .disabled &&
        reassignedResultActionShortcuts.choice(for: .toggleCaseSensitive) == .commandOptionC,
    "result action shortcut settings should participate in duplicate clearing"
)

let legacyShortcutSettingsData = Data(
    """
    {
      "quickSearch": "commandOptionSpace",
      "showWindow": "command1",
      "reindex": "controlCommandR"
    }
    """.utf8
)
let decodedLegacyShortcutSettings = try! JSONDecoder().decode(
    AppShortcutSettings.self,
    from: legacyShortcutSettingsData
)
expect(
    decodedLegacyShortcutSettings.choice(for: .quickSearch) == .commandOptionSpace &&
        decodedLegacyShortcutSettings.choice(for: .showWindow) == .command1 &&
        decodedLegacyShortcutSettings.choice(for: .openSelected) == .disabled &&
        decodedLegacyShortcutSettings.choice(for: .revealSelected) == .disabled &&
        decodedLegacyShortcutSettings.choice(for: .copySelectedPath) == .disabled &&
        decodedLegacyShortcutSettings.choice(for: .reindex) == .controlCommandR &&
        decodedLegacyShortcutSettings.choice(for: .toggleRegexMatching) == .disabled &&
        decodedLegacyShortcutSettings.choice(for: .toggleWholeWordMatching) == .disabled &&
        decodedLegacyShortcutSettings.choice(for: .toggleDiacriticSensitive) == .disabled,
    "legacy shortcut settings should decode with defaults for newly added actions"
)

for action in AppShortcutAction.allCases {
    expect(
        action.availableChoices.contains(defaultShortcuts.choice(for: action)),
        "default shortcut should be selectable for \(action.rawValue)"
    )
    expect(
        action.availableChoices.contains(.disabled),
        "shortcut action should always allow disabling \(action.rawValue)"
    )
}

expect(
    SearchCandidateHint(
        terms: ["go"],
        canUseDatabaseCandidates: true
    ).databaseCandidateLimit(requestedWindowEnd: 500) == 4_000,
    "short broad terms should keep a wide SQLite candidate window"
)

expect(
    SearchCandidateHint(
        terms: ["swift"],
        canUseDatabaseCandidates: true
    ).databaseCandidateLimit(requestedWindowEnd: 500) == 2_000,
    "specific single terms should use a tighter SQLite candidate window"
)

expect(
    SearchCandidateHint(
        terms: ["launch", "notes"],
        canUseDatabaseCandidates: true
    ).databaseCandidateLimit(requestedWindowEnd: 500) == 1_500,
    "multi-term searches should use a tighter SQLite candidate window"
)

expect(
    SearchCandidateHint(
        terms: ["launch"],
        canUseDatabaseCandidates: true,
        extensions: ["swift"]
    ).databaseCandidateLimit(requestedWindowEnd: 500) == 1_000,
    "structured text searches should use a tighter SQLite candidate window"
)

expect(
    SearchCandidateHint(
        terms: [],
        canUseDatabaseCandidates: true,
        extensions: ["swift"]
    ).databaseCandidateLimit(requestedWindowEnd: 500) == 2_000,
    "structured-only searches should keep enough SQLite candidates for result windows"
)

func httpGet(port: UInt16, path: String, timeoutSeconds: Int = 5) throws -> String {
    let fd = Darwin.socket(AF_INET, SOCK_STREAM, 0)
    guard fd >= 0 else {
        throw NSError(domain: "MacThingSelfTest", code: 1)
    }
    defer {
        Darwin.close(fd)
    }

    var timeout = timeval(tv_sec: timeoutSeconds, tv_usec: 0)
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = port.bigEndian
    address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

    let connectResult = withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
            Darwin.connect(fd, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard connectResult == 0 else {
        throw NSError(domain: "MacThingSelfTest", code: 2)
    }

    let request = "GET \(path) HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n"
    request.withCString { pointer in
        _ = Darwin.write(fd, pointer, strlen(pointer))
    }
    Darwin.shutdown(fd, SHUT_WR)

    var response = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while true {
        let count = buffer.withUnsafeMutableBytes { rawBuffer in
            Darwin.read(fd, rawBuffer.baseAddress, rawBuffer.count)
        }
        if count <= 0 {
            break
        }
        response.append(buffer, count: count)
    }

    return String(decoding: response, as: UTF8.self)
}

let nameMatch = FileEntry(
    path: "/Users/me/Documents/Project Notes.md",
    name: "Project Notes.md",
    parent: "/Users/me/Documents",
    kind: .file,
    byteSize: 10,
    modifiedAt: Date(timeIntervalSince1970: 1_000)
)
let pathMatch = FileEntry(
    path: "/Users/me/project/archive/readme.txt",
    name: "readme.txt",
    parent: "/Users/me/project/archive",
    kind: .file,
    byteSize: 10,
    modifiedAt: Date(timeIntervalSince1970: 2_000)
)
let deepPathMatch = FileEntry(
    path: "/Users/me/project/archive/deep/readme.txt",
    name: "readme.txt",
    parent: "/Users/me/project/archive/deep",
    kind: .file,
    byteSize: 10,
    modifiedAt: Date(timeIntervalSince1970: 2_100)
)
let sidecarAudio = FileEntry(
    path: "/Users/me/Music/Track.mp3",
    name: "Track.mp3",
    parent: "/Users/me/Music",
    kind: .file,
    byteSize: 128,
    modifiedAt: Date(timeIntervalSince1970: 2_200)
)
let sidecarImage = FileEntry(
    path: "/Users/me/Music/Track.jpg",
    name: "Track.jpg",
    parent: "/Users/me/Music",
    kind: .file,
    byteSize: 256,
    modifiedAt: Date(timeIntervalSince1970: 2_300)
)
let matchingFolderFile = FileEntry(
    path: "/Users/me/Projects/Archive.txt",
    name: "Archive.txt",
    parent: "/Users/me/Projects",
    kind: .file,
    byteSize: 512,
    modifiedAt: Date(timeIntervalSince1970: 2_400)
)
let matchingFolder = FileEntry(
    path: "/Users/me/Projects/Archive",
    name: "Archive",
    parent: "/Users/me/Projects",
    kind: .folder,
    byteSize: nil,
    modifiedAt: Date(timeIntervalSince1970: 2_500)
)
let semicolonName = FileEntry(
    path: "/Users/me/Documents/Semi;Colon.txt",
    name: "Semi;Colon.txt",
    parent: "/Users/me/Documents",
    kind: .file,
    byteSize: 32,
    modifiedAt: Date(timeIntervalSince1970: 2_600)
)
let semiDistractor = FileEntry(
    path: "/Users/me/Documents/Semi.txt",
    name: "Semi.txt",
    parent: "/Users/me/Documents",
    kind: .file,
    byteSize: 16,
    modifiedAt: Date(timeIntervalSince1970: 2_700)
)
let colonDistractor = FileEntry(
    path: "/Users/me/Documents/Colon.txt",
    name: "Colon.txt",
    parent: "/Users/me/Documents",
    kind: .file,
    byteSize: 16,
    modifiedAt: Date(timeIntervalSince1970: 2_800)
)
let pipeName = FileEntry(
    path: "/Users/me/Documents/Pipe|Name.txt",
    name: "Pipe|Name.txt",
    parent: "/Users/me/Documents",
    kind: .file,
    byteSize: 32,
    modifiedAt: Date(timeIntervalSince1970: 2_900)
)
let literalMacroName = FileEntry(
    path: "/Users/me/Documents/Quote\" & <Live> 'Mix'.txt",
    name: "Quote\" & <Live> 'Mix'.txt",
    parent: "/Users/me/Documents",
    kind: .file,
    byteSize: 32,
    modifiedAt: Date(timeIntervalSince1970: 2_920)
)
let nameDistractor = FileEntry(
    path: "/Users/me/Documents/Name.txt",
    name: "Name.txt",
    parent: "/Users/me/Documents",
    kind: .file,
    byteSize: 16,
    modifiedAt: Date(timeIntervalSince1970: 2_950)
)
let regularName = FileEntry(
    path: "/Users/me/Documents/Regular.txt",
    name: "Regular.txt",
    parent: "/Users/me/Documents",
    kind: .file,
    byteSize: 24,
    modifiedAt: Date(timeIntervalSince1970: 2_975)
)
let duplicatedExtension = FileEntry(
    path: "/Users/me/Photos/Cover.jpg.jpg",
    name: "Cover.jpg.jpg",
    parent: "/Users/me/Photos",
    kind: .file,
    byteSize: 64,
    modifiedAt: Date(timeIntervalSince1970: 2_980)
)
let singleExtension = FileEntry(
    path: "/Users/me/Photos/Cover.jpg",
    name: "Cover.jpg",
    parent: "/Users/me/Photos",
    kind: .file,
    byteSize: 64,
    modifiedAt: Date(timeIntervalSince1970: 2_985)
)
let rootLevelEntry = FileEntry(
    path: "/Applications",
    name: "Applications",
    parent: "/",
    kind: .folder,
    byteSize: nil,
    modifiedAt: Date(timeIntervalSince1970: 3_000)
)

let projectResults = SearchEngine.search(query: "project", in: [nameMatch, pathMatch])
expect(
    projectResults.map(\.path) == [nameMatch.path, pathMatch.path],
    "name matches should sort ahead of path-only matches"
)

let countedProjectResults = SearchEngine.search(
    request: SearchRequest(query: "project count:1"),
    in: [nameMatch, pathMatch]
)
expect(
    countedProjectResults.entries.map(\.path) == [nameMatch.path] &&
        countedProjectResults.totalMatches == 2,
    "count: should limit non-empty search result windows while preserving total match counts"
)

let pathModifierResults = SearchEngine.search(
    request: SearchRequest(
        query: "path:project",
        options: SearchOptions(matchPath: false)
    ),
    in: [nameMatch, pathMatch]
)
expect(
    pathModifierResults.entries.map(\.path) == [nameMatch.path, pathMatch.path],
    "path: should enable path matching for a single term"
)

let noPathModifierResults = SearchEngine.search(query: "nopath:project", in: [nameMatch, pathMatch])
expect(
    noPathModifierResults.map(\.path) == [nameMatch.path],
    "nopath: should restrict a single term to names"
)

expect(
    SearchEngine.search(query: "name:<Project Notes>", in: [nameMatch, pathMatch]).map(\.path) ==
        [nameMatch.path],
    "function value sub-expressions should AND space-delimited inner terms"
)

expect(
    Set(SearchEngine.search(query: "name:<Project|readme>", in: [nameMatch, pathMatch, deepPathMatch]).map(\.path)) ==
        Set([nameMatch.path, pathMatch.path, deepPathMatch.path]),
    "function value sub-expressions should preserve inner OR operators"
)

expect(
    SearchEngine.search(query: "stem:.$extension:", in: [duplicatedExtension, singleExtension]).map(\.path) ==
        [duplicatedExtension.path],
    "string search functions should substitute current-entry property values"
)

expect(
    SearchEngine.search(query: "filelist:readme.txt", in: [nameMatch, pathMatch]).map(\.path) ==
        [pathMatch.path],
    "filelist: should match pipe-delimited filename lists"
)

expect(
    Set(SearchEngine.search(query: "filelist:readme.*", in: [nameMatch, pathMatch, deepPathMatch]).map(\.path)) ==
        Set([pathMatch.path, deepPathMatch.path]),
    "filelist: should support wildcard filename list values"
)

expect(
    SearchEngine.search(query: "path:filelist:/Users/me/project/archive/readme.txt", in: [nameMatch, pathMatch, deepPathMatch]).map(\.path) ==
        [pathMatch.path],
    "path:filelist: should match pipe-delimited full path lists"
)

expect(
    SearchEngine.search(query: "filelist:/Users/me/project/*/readme.txt", in: [pathMatch, deepPathMatch]).map(\.path) ==
        [pathMatch.path],
    "filelist: path wildcards should keep * within a single path component"
)

expect(
    Set(SearchEngine.search(query: "filelist:/Users/me/project/**/readme.txt", in: [pathMatch, deepPathMatch]).map(\.path)) ==
        Set([pathMatch.path, deepPathMatch.path]),
    "filelist: path wildcards should let ** cross path separators"
)

expect(
    SearchEngine.search(
        query: "name:\"Semi;Colon.txt\"",
        in: [semicolonName, semiDistractor, colonDistractor]
    ).map(\.path) == [semicolonName.path],
    "quoted semicolons should be treated as literal function value text"
)

expect(
    Set(SearchEngine.search(
        query: "name:\"Semi;Colon.txt\";Regular.txt",
        in: [semicolonName, semiDistractor, colonDistractor, regularName]
    ).map(\.path)) == Set([semicolonName.path, regularName.path]),
    "semicolon OR lists should ignore semicolons escaped inside quotes"
)

expect(
    Set(SearchEngine.search(
        query: "filelist:\"Semi;Colon.txt\";Regular.txt",
        in: [semicolonName, semiDistractor, colonDistractor, regularName]
    ).map(\.path)) == Set([semicolonName.path, regularName.path]),
    "filelist: should preserve quoted semicolons inside exact filename values"
)

expect(
    SearchEngine.search(
        query: "filelist:\"Pipe|Name.txt\"",
        in: [pipeName, nameDistractor]
    ).map(\.path) == [pipeName.path],
    "filelist: should preserve quoted pipe characters inside exact filename values"
)

expect(
    SearchEngine.search(
        query: "name:Quotequot:",
        in: [literalMacroName, nameDistractor]
    ).map(\.path) == [literalMacroName.path],
    "quot: should search for a literal double quote"
)

expect(
    SearchEngine.search(
        query: "name:#34:",
        in: [literalMacroName, nameDistractor]
    ).map(\.path) == [literalMacroName.path],
    "decimal unicode macros should search for literal characters"
)

expect(
    SearchEngine.search(
        query: "name:amp:",
        in: [literalMacroName, nameDistractor]
    ).map(\.path) == [literalMacroName.path],
    "amp: should search for a literal ampersand"
)

expect(
    SearchEngine.search(
        query: "name:apos:Mixapos:",
        in: [literalMacroName, nameDistractor]
    ).map(\.path) == [literalMacroName.path],
    "apos: should search for a literal apostrophe"
)

expect(
    SearchEngine.search(
        query: "name:lt:Livegt:",
        in: [literalMacroName, nameDistractor]
    ).map(\.path) == [literalMacroName.path],
    "lt: and gt: should search for literal angle brackets"
)

expect(
    SearchEngine.search(
        query: "name:Semi#59:Colon.txt",
        in: [semicolonName, semiDistractor, colonDistractor]
    ).map(\.path) == [semicolonName.path],
    "unicode separator macros should stay literal inside function values"
)

expect(
    SearchEngine.search(
        query: "name:#x3C:Live#x3E:",
        in: [literalMacroName, nameDistractor]
    ).map(\.path) == [literalMacroName.path],
    "hex unicode macros should search for literal unicode scalars"
)

expect(
    EverythingSearchCommand.parse("/close") == .close &&
        EverythingSearchCommand.parse("/closeall") == .closeAll &&
        EverythingSearchCommand.parse("/quit") == .quit &&
        EverythingSearchCommand.parse("/exit") == .quit,
    "Everything search commands should parse close and quit aliases"
)

expect(
    EverythingSearchCommand.parse("/rebuild") == .rebuild &&
        EverythingSearchCommand.parse("/reindex") == .rebuild &&
        EverythingSearchCommand.parse("/update /Users/me/Documents") == .update(path: "/Users/me/Documents"),
    "Everything search commands should parse rebuild and update aliases"
)

expect(
    EverythingSearchCommand.parse("about:home") == .home &&
        EverythingSearchCommand.parse("about:options") == .options &&
        EverythingSearchCommand.parse("about:") == .about,
    "Everything about: commands should parse supported actions"
)

expect(
    EverythingSearchCommand.parse("/debug") == .unsupported("debug") &&
        EverythingSearchCommand.parse("regular search") == nil,
    "unsupported slash commands should be recognized without stealing normal searches"
)

let offlineFileListEntry = FileEntry(
    path: "/Volumes/Archive/Launch.mkv",
    name: "Launch.mkv",
    parent: "/Volumes/Archive",
    kind: .file,
    byteSize: 100,
    modifiedAt: Date(timeIntervalSince1970: 3_050)
).markingFileListSource(
    name: "Offline Media.efu",
    path: "/Users/me/File Lists/Offline Media.efu"
)

expect(
    SearchEngine.search(query: "filelistfilename:\"Offline Media.efu\"", in: [offlineFileListEntry, pathMatch]).map(\.path) ==
        [offlineFileListEntry.path],
    "filelistfilename: should match entries imported from a named file list"
)

expect(
    SearchEngine.search(query: "filelistfilename:Offline*", in: [offlineFileListEntry, pathMatch]).map(\.path) ==
        [offlineFileListEntry.path],
    "filelistfilename: should support wildcard file-list names"
)

expect(
    SearchEngine.search(query: "filelistfilename:\"/Users/me/File Lists/Offline Media.efu\"", in: [offlineFileListEntry, pathMatch]).map(\.path) ==
        [offlineFileListEntry.path],
    "filelistfilename: should match file-list source paths"
)

expect(
    SearchEngine.search(query: "filelistfilename:", in: [offlineFileListEntry, pathMatch]).map(\.path) ==
        [offlineFileListEntry.path],
    "empty filelistfilename: should match any entry with file-list provenance"
)

expect(
    SearchEngine.search(query: "full-path:/Users/me/project/archive/readme.txt", in: [nameMatch, pathMatch, deepPathMatch]).map(\.path) ==
        [pathMatch.path],
    "full-path: should search full path and filename text"
)

expect(
    SearchEngine.search(query: "path-and-name:archive/deep/readme", in: [pathMatch, deepPathMatch]).map(\.path) ==
        [deepPathMatch.path],
    "path-and-name: should alias full-path:"
)

expect(
    SearchEngine.search(query: "parse-path-name:/Users/me/project/*/readme.txt", in: [pathMatch, deepPathMatch]).map(\.path) ==
        [pathMatch.path],
    "parse-path-name: should support full path wildcard matching"
)

expect(
    Set(SearchEngine.search(query: "full-path:/Applications;/Users/me/project/archive/readme.txt", in: [rootLevelEntry, pathMatch, deepPathMatch]).map(\.path)) ==
        Set([rootLevelEntry.path, pathMatch.path]),
    "full-path: should support semicolon OR lists"
)

expect(
    SearchEngine.search(query: "ext:mp3 file-exists:$stem:.jpg", in: [sidecarAudio, sidecarImage]).map(\.path) ==
        [sidecarAudio.path],
    "file-exists: should support stem substitution in the same parent folder"
)

expect(
    SearchEngine.search(query: "ext:mp3 file-exists:*.jpg", in: [sidecarAudio, sidecarImage]).map(\.path) ==
        [sidecarAudio.path],
    "file-exists: should support wildcard sibling filename checks"
)

expect(
    SearchEngine.search(query: "ext:mp3 exists:$parent:/Track.jpg", in: [sidecarAudio, sidecarImage]).map(\.path) ==
        [sidecarAudio.path],
    "exists: should support parent substitution for full path checks"
)

expect(
    SearchEngine.search(query: "ext:txt folder-exists:$stem:", in: [matchingFolderFile, matchingFolder]).map(\.path) ==
        [matchingFolderFile.path],
    "folder-exists: should restrict existence checks to folders"
)

expect(
    SearchEngine.search(query: "root:", in: [rootLevelEntry, nameMatch]).map(\.path) == [rootLevelEntry.path],
    "root: should match entries with no indexed parent above them"
)

expect(
    SearchEngine.search(query: "depth:0", in: [rootLevelEntry, nameMatch]).map(\.path) == [rootLevelEntry.path],
    "depth:0 should match root-level entries"
)

let selfTestHomePath = FileManager.default.homeDirectoryForCurrentUser.path
let selfTestDesktopPath = URL(fileURLWithPath: selfTestHomePath).appendingPathComponent("Desktop").path
let shellDesktopFolder = FileEntry(
    path: selfTestDesktopPath,
    name: "Desktop",
    parent: selfTestHomePath,
    kind: .folder,
    byteSize: nil,
    modifiedAt: Date(timeIntervalSince1970: 20)
)
let shellDesktopFile = FileEntry(
    path: URL(fileURLWithPath: selfTestDesktopPath).appendingPathComponent("Launch.txt").path,
    name: "Launch.txt",
    parent: selfTestDesktopPath,
    kind: .file,
    byteSize: 10,
    modifiedAt: Date(timeIntervalSince1970: 21)
)
let shellNestedDesktopFile = FileEntry(
    path: URL(fileURLWithPath: selfTestDesktopPath).appendingPathComponent("Projects/Launch.md").path,
    name: "Launch.md",
    parent: URL(fileURLWithPath: selfTestDesktopPath).appendingPathComponent("Projects").path,
    kind: .file,
    byteSize: 10,
    modifiedAt: Date(timeIntervalSince1970: 22)
)
let shellDocumentFile = FileEntry(
    path: URL(fileURLWithPath: selfTestHomePath).appendingPathComponent("Documents/Launch.txt").path,
    name: "Launch.txt",
    parent: URL(fileURLWithPath: selfTestHomePath).appendingPathComponent("Documents").path,
    kind: .file,
    byteSize: 10,
    modifiedAt: Date(timeIntervalSince1970: 23)
)
let shellDesktopResults = SearchEngine.search(
    query: "shell:desktop",
    in: [shellDesktopFolder, shellDesktopFile, shellNestedDesktopFile, shellDocumentFile]
)
expect(
    Set(shellDesktopResults.map(\.path)) == Set([shellDesktopFolder.path, shellDesktopFile.path, shellNestedDesktopFile.path]),
    "shell:desktop should match the known folder itself and all indexed descendants"
)

let unknownShellResponse = SearchEngine.search(
    request: SearchRequest(query: "shell:not-a-real-folder"),
    in: [shellDesktopFile]
)
expect(
    unknownShellResponse.entries.isEmpty && unknownShellResponse.warnings.contains { $0.contains("shell:not-a-real-folder") },
    "unknown shell: folder names should produce a warning and no matches"
)

let older = FileEntry(
    path: "/a/older.txt",
    name: "older.txt",
    parent: "/a",
    kind: .file,
    byteSize: 10,
    modifiedAt: Date(timeIntervalSince1970: 1)
)
let newer = FileEntry(
    path: "/a/newer.txt",
    name: "newer.txt",
    parent: "/a",
    kind: .file,
    byteSize: 10,
    modifiedAt: Date(timeIntervalSince1970: 2)
)

let recentResults = SearchEngine.search(query: "", in: [older, newer])
expect(
    recentResults.map(\.path) == [newer.path, older.path],
    "empty search should sort by recency"
)

let offsetResults = SearchEngine.search(
    request: SearchRequest(query: "", limit: 1, offset: 1),
    in: [older, newer]
)
expect(
    offsetResults.entries.map(\.path) == [older.path] &&
        offsetResults.totalMatches == 2,
    "search requests should support offset windows while preserving total match counts"
)

let countOnlyResults = SearchEngine.search(
    request: SearchRequest(query: "count:1"),
    in: [older, newer]
)
expect(
    countOnlyResults.entries.map(\.path) == [newer.path] &&
        countOnlyResults.totalMatches == 2,
    "count: should limit empty-search result windows while preserving total match counts"
)

let manyRecentEntries = (0..<2_000).map { index in
    FileEntry(
        path: "/bulk/item-\(index).txt",
        name: "item-\(index).txt",
        parent: "/bulk",
        kind: .file,
        byteSize: Int64(index),
        modifiedAt: Date(timeIntervalSince1970: TimeInterval(index))
    )
}
let boundedRecentResults = SearchEngine.search(
    request: SearchRequest(query: "", limit: 5),
    in: manyRecentEntries
)
expect(
    boundedRecentResults.entries.map(\.path) == [
        "/bulk/item-1999.txt",
        "/bulk/item-1998.txt",
        "/bulk/item-1997.txt",
        "/bulk/item-1996.txt",
        "/bulk/item-1995.txt"
    ] &&
        boundedRecentResults.totalMatches == manyRecentEntries.count,
    "large empty searches should preserve total matches while returning the bounded recency window"
)
expect(
    boundedRecentResults.diagnostics?.source == .memory &&
        boundedRecentResults.diagnostics?.searchedEntryCount == manyRecentEntries.count &&
        boundedRecentResults.diagnostics?.builtFullContext == false,
    "search responses should report memory search diagnostics"
)

let simpleTextDiagnostics = SearchEngine.search(
    request: SearchRequest(query: "item-1999", limit: 5),
    in: manyRecentEntries
)
expect(
    simpleTextDiagnostics.diagnostics?.builtFullContext == false,
    "simple text searches should skip full search context"
)

let compactMatch = FileEntry(
    path: "/Users/me/Screenshots/QuarterlyRoadmap.png",
    name: "QuarterlyRoadmap.png",
    parent: "/Users/me/Screenshots",
    kind: .file,
    byteSize: 10,
    modifiedAt: nil
)

let fuzzyResults = SearchEngine.search(query: "qrm", in: [compactMatch])
expect(
    fuzzyResults.first?.path == compactMatch.path,
    "subsequence queries should match compact filename abbreviations"
)

let wholeWordMatch = FileEntry(
    path: "/Users/me/Documents/Cat Video.txt",
    name: "Cat Video.txt",
    parent: "/Users/me/Documents",
    kind: .file,
    byteSize: 10,
    modifiedAt: Date(timeIntervalSince1970: 10)
)
let partialWordMatch = FileEntry(
    path: "/Users/me/Documents/Concatenate.txt",
    name: "Concatenate.txt",
    parent: "/Users/me/Documents",
    kind: .file,
    byteSize: 10,
    modifiedAt: Date(timeIntervalSince1970: 11)
)
let underscoredWordMatch = FileEntry(
    path: "/Users/me/Documents/cat_video.txt",
    name: "cat_video.txt",
    parent: "/Users/me/Documents",
    kind: .file,
    byteSize: 10,
    modifiedAt: Date(timeIntervalSince1970: 12)
)
let wholeWordResults = SearchEngine.search(
    request: SearchRequest(
        query: "cat",
        options: SearchOptions(wholeWordMatching: true)
    ),
    in: [wholeWordMatch, partialWordMatch, underscoredWordMatch]
)
expect(
    wholeWordResults.entries.map(\.path) == [wholeWordMatch.path],
    "whole-word matching should reject partial and underscore-joined filename matches"
)

let wholeWordModifierResults = SearchEngine.search(query: "wholeword:cat", in: [wholeWordMatch, partialWordMatch])
expect(
    wholeWordModifierResults.map(\.path) == [wholeWordMatch.path],
    "wholeword: should enable whole-word matching for a single term"
)

let noWholeWordModifierResults = SearchEngine.search(
    request: SearchRequest(
        query: "nowholeword:cat",
        options: SearchOptions(wholeWordMatching: true)
    ),
    in: [wholeWordMatch, partialWordMatch]
)
expect(
    Set(noWholeWordModifierResults.entries.map(\.path)) == Set([wholeWordMatch.path, partialWordMatch.path]),
    "nowholeword: should override a whole-word search option for one term"
)

let cafePlain = FileEntry(
    path: "/Users/me/Documents/Cafe.txt",
    name: "Cafe.txt",
    parent: "/Users/me/Documents",
    kind: .file,
    byteSize: 10,
    modifiedAt: Date(timeIntervalSince1970: 13)
)
let cafeAccented = FileEntry(
    path: "/Users/me/Documents/Café.txt",
    name: "Café.txt",
    parent: "/Users/me/Documents",
    kind: .file,
    byteSize: 10,
    modifiedAt: Date(timeIntervalSince1970: 14)
)
let diacriticFoldedResults = SearchEngine.search(
    request: SearchRequest(query: "cafe"),
    in: [cafePlain, cafeAccented]
)
expect(
    Set(diacriticFoldedResults.entries.map(\.path)) == Set([cafePlain.path, cafeAccented.path]),
    "default matching should fold diacritics"
)

let diacriticSensitiveResults = SearchEngine.search(
    request: SearchRequest(
        query: "cafe",
        options: SearchOptions(diacriticSensitive: true)
    ),
    in: [cafePlain, cafeAccented]
)
expect(
    diacriticSensitiveResults.entries.map(\.path) == [cafePlain.path],
    "diacritic-sensitive matching should distinguish accented characters"
)

let wildcardDiacriticFoldedResults = SearchEngine.search(
    request: SearchRequest(query: "*cafe*"),
    in: [cafePlain, cafeAccented]
)
expect(
    Set(wildcardDiacriticFoldedResults.entries.map(\.path)) == Set([cafePlain.path, cafeAccented.path]),
    "wildcard matching should fold diacritics by default"
)

let wildcardDiacriticSensitiveResults = SearchEngine.search(
    request: SearchRequest(
        query: "*cafe*",
        options: SearchOptions(diacriticSensitive: true)
    ),
    in: [cafePlain, cafeAccented]
)
expect(
    wildcardDiacriticSensitiveResults.entries.map(\.path) == [cafePlain.path],
    "diacritic-sensitive wildcard matching should distinguish accented characters"
)

let regexDiacriticFoldedResults = SearchEngine.search(
    request: SearchRequest(query: "regex:^cafe"),
    in: [cafePlain, cafeAccented]
)
expect(
    Set(regexDiacriticFoldedResults.entries.map(\.path)) == Set([cafePlain.path, cafeAccented.path]),
    "regex matching should fold diacritics by default"
)

let regexDiacriticSensitiveResults = SearchEngine.search(
    request: SearchRequest(
        query: "regex:^cafe",
        options: SearchOptions(diacriticSensitive: true)
    ),
    in: [cafePlain, cafeAccented]
)
expect(
    regexDiacriticSensitiveResults.entries.map(\.path) == [cafePlain.path],
    "diacritic-sensitive regex matching should distinguish accented characters"
)

let upperReport = FileEntry(
    path: "/Users/me/Documents/Report.txt",
    name: "Report.txt",
    parent: "/Users/me/Documents",
    kind: .file,
    byteSize: 10,
    modifiedAt: Date(timeIntervalSince1970: 15)
)
let lowerReport = FileEntry(
    path: "/Users/me/Documents/report.txt",
    name: "report.txt",
    parent: "/Users/me/Documents",
    kind: .file,
    byteSize: 10,
    modifiedAt: Date(timeIntervalSince1970: 16)
)
let modifierEntries = [upperReport, lowerReport]
expect(
    SearchEngine.search(query: "case:Report", in: modifierEntries).map(\.path) == [upperReport.path],
    "case: should make a single term case-sensitive"
)
expect(
    Set(SearchEngine.search(
        request: SearchRequest(
            query: "nocase:Report",
            options: SearchOptions(caseSensitive: true)
        ),
        in: modifierEntries
    ).entries.map(\.path)) == Set([upperReport.path, lowerReport.path]),
    "nocase: should override a case-sensitive search option for one term"
)
expect(
    SearchEngine.search(query: "diacritics:cafe", in: [cafePlain, cafeAccented]).map(\.path) == [cafePlain.path],
    "diacritics: should make a single term accent-sensitive"
)
expect(
    Set(SearchEngine.search(
        request: SearchRequest(
            query: "nodiacritics:cafe",
            options: SearchOptions(diacriticSensitive: true)
        ),
        in: [cafePlain, cafeAccented]
    ).entries.map(\.path)) == Set([cafePlain.path, cafeAccented.path]),
    "nodiacritics: should override an accent-sensitive search option for one term"
)
expect(
    SearchEngine.search(query: "case:regex:^Report", in: modifierEntries).map(\.path) == [upperReport.path],
    "modifier chains should apply to regex terms"
)
expect(
    SearchEngine.search(
        request: SearchRequest(
            query: "case:^Report",
            options: SearchOptions(regexMatching: true)
        ),
        in: modifierEntries
    ).entries.map(\.path) == [upperReport.path],
    "regex search option should treat plain terms as regular expressions"
)
expect(
    Set(SearchEngine.search(
        request: SearchRequest(
            query: "noregex:Report",
            options: SearchOptions(regexMatching: true)
        ),
        in: modifierEntries
    ).entries.map(\.path)) == Set([upperReport.path, lowerReport.path]),
    "noregex: should override the regex search option for one term"
)
expect(
    SearchEngine.search(query: "case:wildcards:Rep*.txt", in: modifierEntries).map(\.path) == [upperReport.path],
    "modifier chains should apply to wildcard terms"
)
expect(
    SearchEngine.search(query: "nowildcards:Rep*.txt", in: modifierEntries).isEmpty,
    "nowildcards: should treat wildcard characters as literal text"
)

let legacySearchOptions = try JSONDecoder().decode(
    SearchOptions.self,
    from: Data(#"{"matchPath":true,"fuzzyMatching":true,"caseSensitive":false}"#.utf8)
)
expect(
    legacySearchOptions.wholeWordMatching == false &&
        legacySearchOptions.regexMatching == false &&
        legacySearchOptions.diacriticSensitive == false,
    "legacy search options should default new matching options to off"
)

let photo = FileEntry(
    path: "/Users/me/Pictures/Launch.JPG",
    name: "Launch.JPG",
    parent: "/Users/me/Pictures",
    kind: .file,
    byteSize: 2_500_000,
    createdAt: Date(timeIntervalSince1970: 900),
    modifiedAt: Date(),
    indexedAt: Date()
)
let document = FileEntry(
    path: "/Users/me/Documents/Launch Notes.md",
    name: "Launch Notes.md",
    parent: "/Users/me/Documents",
    kind: .file,
    byteSize: 2_000,
    modifiedAt: Date(timeIntervalSince1970: 1_500),
    indexedAt: Date(timeIntervalSince1970: 1_500)
)
let utf8NameEntry = FileEntry(
    path: "/Users/me/Documents/Café.txt",
    name: "Café.txt",
    parent: "/Users/me/Documents",
    kind: .file,
    byteSize: 128,
    modifiedAt: Date(timeIntervalSince1970: 1_600),
    indexedAt: Date(timeIntervalSince1970: 1_600)
)
let emojiNameEntry = FileEntry(
    path: "/Users/me/Documents/😀.txt",
    name: "😀.txt",
    parent: "/Users/me/Documents",
    kind: .file,
    byteSize: 256,
    modifiedAt: Date(timeIntervalSince1970: 1_700),
    indexedAt: Date(timeIntervalSince1970: 1_700)
)
let folder = FileEntry(
    path: "/Users/me/Documents/Launch",
    name: "Launch",
    parent: "/Users/me/Documents",
    kind: .folder,
    byteSize: nil,
    modifiedAt: Date(timeIntervalSince1970: 2_500),
    indexedAt: Date(timeIntervalSince1970: 2_500)
)
let emptyFile = FileEntry(
    path: "/Users/me/Documents/Empty.txt",
    name: "Empty.txt",
    parent: "/Users/me/Documents",
    kind: .file,
    byteSize: 0,
    modifiedAt: Date(timeIntervalSince1970: 2_600),
    indexedAt: Date(timeIntervalSince1970: 2_600)
)
let duplicateA = FileEntry(
    path: "/Users/me/A/Duplicate.md",
    name: "Duplicate.md",
    parent: "/Users/me/A",
    kind: .file,
    byteSize: 20,
    modifiedAt: Date(timeIntervalSince1970: 2_700),
    indexedAt: Date(timeIntervalSince1970: 2_700)
)
let duplicateB = FileEntry(
    path: "/Users/me/B/Duplicate.md",
    name: "Duplicate.md",
    parent: "/Users/me/B",
    kind: .file,
    byteSize: 30,
    modifiedAt: Date(timeIntervalSince1970: 2_800),
    indexedAt: Date(timeIntervalSince1970: 2_800)
)
let sameNamePartText = FileEntry(
    path: "/Users/me/Dupes/Budget.txt",
    name: "Budget.txt",
    parent: "/Users/me/Dupes",
    kind: .file,
    byteSize: 512,
    createdAt: Date(timeIntervalSince1970: 4_100),
    modifiedAt: Date(timeIntervalSince1970: 4_200),
    accessedAt: Date(timeIntervalSince1970: 4_300),
    indexedAt: Date(timeIntervalSince1970: 4_400),
    attributes: [.file, .hidden]
)
let sameNamePartMarkdown = FileEntry(
    path: "/Users/me/Dupes/Budget.md",
    name: "Budget.md",
    parent: "/Users/me/Dupes",
    kind: .file,
    byteSize: 512,
    createdAt: Date(timeIntervalSince1970: 4_100),
    modifiedAt: Date(timeIntervalSince1970: 4_200),
    accessedAt: Date(timeIntervalSince1970: 4_300),
    indexedAt: Date(timeIntervalSince1970: 4_500),
    attributes: [.file, .hidden]
)
let uniqueDuplicateMetricEntry = FileEntry(
    path: "/Users/me/Dupes/Agenda.md",
    name: "Agenda.md",
    parent: "/Users/me/Dupes",
    kind: .file,
    byteSize: 513,
    createdAt: Date(timeIntervalSince1970: 4_600),
    modifiedAt: Date(timeIntervalSince1970: 4_700),
    accessedAt: Date(timeIntervalSince1970: 4_800),
    indexedAt: Date(timeIntervalSince1970: 4_900),
    attributes: [.file, .readonly]
)
let duplicateMetricEntries = [sameNamePartText, sameNamePartMarkdown, uniqueDuplicateMetricEntry]
let childInFolder = FileEntry(
    path: "/Users/me/Documents/Launch/Child.txt",
    name: "Child.txt",
    parent: "/Users/me/Documents/Launch",
    kind: .file,
    byteSize: 12,
    modifiedAt: Date(timeIntervalSince1970: 2_900),
    indexedAt: Date(timeIntervalSince1970: 2_900)
)
let hiddenChildInFolder = FileEntry(
    path: "/Users/me/Documents/Launch/.HiddenChild",
    name: ".HiddenChild",
    parent: "/Users/me/Documents/Launch",
    kind: .file,
    byteSize: 8,
    modifiedAt: Date(timeIntervalSince1970: 2_925),
    indexedAt: Date(timeIntervalSince1970: 2_925),
    attributes: [.file, .hidden]
)
let childFolderInFolder = FileEntry(
    path: "/Users/me/Documents/Launch/Nested",
    name: "Nested",
    parent: "/Users/me/Documents/Launch",
    kind: .folder,
    byteSize: nil,
    modifiedAt: Date(timeIntervalSince1970: 2_950),
    indexedAt: Date(timeIntervalSince1970: 2_950)
)
let childMetadataFileCreatedAt = Calendar.current.date(from: DateComponents(year: 2024, month: 5, day: 1, hour: 12))!
let childMetadataFileModifiedAt = Calendar.current.date(from: DateComponents(year: 2024, month: 5, day: 2, hour: 12))!
let childMetadataFileAccessedAt = Calendar.current.date(from: DateComponents(year: 2024, month: 5, day: 3, hour: 12))!
let childMetadataFileIndexedAt = Calendar.current.date(from: DateComponents(year: 2024, month: 5, day: 4, hour: 12))!
let childMetadataFileLastRunAt = Calendar.current.date(from: DateComponents(year: 2024, month: 5, day: 5, hour: 12))!
let childMetadataFile = FileEntry(
    path: "/Users/me/Documents/Launch/Metadata.bin",
    name: "Metadata.bin",
    parent: "/Users/me/Documents/Launch",
    kind: .file,
    byteSize: 2_048,
    createdAt: childMetadataFileCreatedAt,
    modifiedAt: childMetadataFileModifiedAt,
    accessedAt: childMetadataFileAccessedAt,
    indexedAt: childMetadataFileIndexedAt,
    runCount: 7,
    lastRunAt: childMetadataFileLastRunAt
)
let childMetadataFolderCreatedAt = Calendar.current.date(from: DateComponents(year: 2024, month: 6, day: 1, hour: 12))!
let childMetadataFolderModifiedAt = Calendar.current.date(from: DateComponents(year: 2024, month: 6, day: 2, hour: 12))!
let childMetadataFolder = FileEntry(
    path: "/Users/me/Documents/Launch/MetadataFolder",
    name: "MetadataFolder",
    parent: "/Users/me/Documents/Launch",
    kind: .folder,
    byteSize: 4_096,
    createdAt: childMetadataFolderCreatedAt,
    modifiedAt: childMetadataFolderModifiedAt,
    indexedAt: childMetadataFolderModifiedAt,
    runCount: 3
)
let nestedGrandchild = FileEntry(
    path: "/Users/me/Documents/Launch/Nested/Grandchild.bin",
    name: "Grandchild.bin",
    parent: "/Users/me/Documents/Launch/Nested",
    kind: .file,
    byteSize: 1_000,
    modifiedAt: Date(timeIntervalSince1970: 2_960),
    indexedAt: Date(timeIntervalSince1970: 2_960)
)
let auntFolder = FileEntry(
    path: "/Users/me/Documents/Archive",
    name: "Archive",
    parent: "/Users/me/Documents",
    kind: .folder,
    byteSize: nil,
    modifiedAt: Date(timeIntervalSince1970: 2_975),
    indexedAt: Date(timeIntervalSince1970: 2_975)
)
let metadataParentCreatedAt = Calendar.current.date(from: DateComponents(year: 2024, month: 2, day: 3, hour: 12))!
let metadataParentModifiedAt = Calendar.current.date(from: DateComponents(year: 2024, month: 3, day: 4, hour: 12))!
let metadataParentFolder = FileEntry(
    path: "/Users/me/MetadataParent",
    name: "MetadataParent",
    parent: "/Users/me",
    kind: .folder,
    byteSize: 4_096,
    createdAt: metadataParentCreatedAt,
    modifiedAt: metadataParentModifiedAt,
    indexedAt: metadataParentModifiedAt
)
let metadataParentChild = FileEntry(
    path: "/Users/me/MetadataParent/Child.txt",
    name: "Child.txt",
    parent: "/Users/me/MetadataParent",
    kind: .file,
    byteSize: 64,
    modifiedAt: Date(timeIntervalSince1970: 2_980),
    indexedAt: Date(timeIntervalSince1970: 2_980)
)
let hiddenAncestorFolder = FileEntry(
    path: "/Users/me/.HiddenParent",
    name: ".HiddenParent",
    parent: "/Users/me",
    kind: .folder,
    byteSize: nil,
    modifiedAt: Date(timeIntervalSince1970: 2_980),
    indexedAt: Date(timeIntervalSince1970: 2_980),
    attributes: [.directory, .hidden]
)
let childUnderHiddenAncestor = FileEntry(
    path: "/Users/me/.HiddenParent/Visible.txt",
    name: "Visible.txt",
    parent: "/Users/me/.HiddenParent",
    kind: .file,
    byteSize: 32,
    modifiedAt: Date(timeIntervalSince1970: 2_985),
    indexedAt: Date(timeIntervalSince1970: 2_985)
)
let syntaxEntries = [photo, document, folder, emptyFile, duplicateA, duplicateB, childInFolder]
let kindSubstitutionEntry = FileEntry(
    path: "/Users/me/Documents/File.txt",
    name: "File.txt",
    parent: "/Users/me/Documents",
    kind: .file,
    byteSize: 11,
    modifiedAt: Date(timeIntervalSince1970: 3_000)
)
let sizeSubstitutionEntry = FileEntry(
    path: "/Users/me/Documents/11 bytes.txt",
    name: "11 bytes.txt",
    parent: "/Users/me/Documents",
    kind: .file,
    byteSize: 11,
    modifiedAt: Date(timeIntervalSince1970: 3_010)
)
let attributeSubstitutionEntry = FileEntry(
    path: "/Users/me/Documents/H6.txt",
    name: "H6.txt",
    parent: "/Users/me/Documents",
    kind: .file,
    byteSize: 1,
    modifiedAt: Date(timeIntervalSince1970: 3_020),
    attributes: [.file, .hidden]
)
let identitySearchEntry = FileEntry(
    path: "/Users/me/Documents/Identity.txt",
    name: "Identity.txt",
    parent: "/Users/me/Documents",
    kind: .file,
    byteSize: 64,
    modifiedAt: Date(timeIntervalSince1970: 3_030),
    fileID: "12345",
    volumeID: "678"
)
let otherIdentitySearchEntry = FileEntry(
    path: "/Users/me/Documents/OtherIdentity.txt",
    name: "OtherIdentity.txt",
    parent: "/Users/me/Documents",
    kind: .file,
    byteSize: 64,
    modifiedAt: Date(timeIntervalSince1970: 3_031),
    fileID: "999",
    volumeID: "678"
)
let fsiPrimaryEntry = FileEntry(
    path: "/Volumes/Primary/System.log",
    name: "System.log",
    parent: "/Volumes/Primary",
    kind: .file,
    byteSize: 128,
    modifiedAt: Date(timeIntervalSince1970: 3_032),
    fileID: "1",
    volumeID: "100"
)
let fsiPrimarySiblingEntry = FileEntry(
    path: "/Volumes/Primary/Notes.log",
    name: "Notes.log",
    parent: "/Volumes/Primary",
    kind: .file,
    byteSize: 256,
    modifiedAt: Date(timeIntervalSince1970: 3_033),
    fileID: "2",
    volumeID: "100"
)
let fsiSecondaryEntry = FileEntry(
    path: "/Volumes/Secondary/System.log",
    name: "System.log",
    parent: "/Volumes/Secondary",
    kind: .file,
    byteSize: 128,
    modifiedAt: Date(timeIntervalSince1970: 3_034),
    fileID: "1",
    volumeID: "200"
)
let mediaTaggedEntry = FileEntry(
    path: "/Users/me/Music/Track01.m4a",
    name: "Track01.m4a",
    parent: "/Users/me/Music",
    kind: .file,
    byteSize: 4_096,
    modifiedAt: Date(timeIntervalSince1970: 3_040),
    mediaTitle: "Launch Theme",
    mediaArtist: "Codex Ensemble",
    mediaAlbum: "MacThing Sessions",
    mediaComment: "Everything-style metadata",
    mediaGenre: "Soundtrack",
    mediaTrack: 7,
    mediaYear: 2026
)
let otherMediaTaggedEntry = FileEntry(
    path: "/Users/me/Music/Track02.m4a",
    name: "Track02.m4a",
    parent: "/Users/me/Music",
    kind: .file,
    byteSize: 4_096,
    modifiedAt: Date(timeIntervalSince1970: 3_041),
    mediaTitle: "Quiet Archive",
    mediaArtist: "Another Artist",
    mediaAlbum: "Old Sessions",
    mediaComment: "Archived metadata",
    mediaGenre: "Ambient",
    mediaTrack: 2,
    mediaYear: 1999
)
let hiddenEntry = FileEntry(
    path: "/Users/me/.secret",
    name: ".secret",
    parent: "/Users/me",
    kind: .file,
    byteSize: 64,
    modifiedAt: Date(timeIntervalSince1970: 3_100),
    indexedAt: Date(timeIntervalSince1970: 3_100),
    attributes: [.file, .hidden]
)
let readonlyEntry = FileEntry(
    path: "/Users/me/Documents/Locked.txt",
    name: "Locked.txt",
    parent: "/Users/me/Documents",
    kind: .file,
    byteSize: 128,
    modifiedAt: Date(timeIntervalSince1970: 3_200),
    indexedAt: Date(timeIntervalSince1970: 3_200),
    attributes: [.file, .readonly]
)
let systemEntry = FileEntry(
    path: "/System/Library/CoreServices/SystemVersion.plist",
    name: "SystemVersion.plist",
    parent: "/System/Library/CoreServices",
    kind: .file,
    byteSize: 256,
    modifiedAt: Date(timeIntervalSince1970: 3_300),
    indexedAt: Date(timeIntervalSince1970: 3_300),
    attributes: [.file, .system]
)
let symlinkEntry = FileEntry(
    path: "/Users/me/Documents/Latest",
    name: "Latest",
    parent: "/Users/me/Documents",
    kind: .symlink,
    byteSize: nil,
    modifiedAt: Date(timeIntervalSince1970: 3_400),
    indexedAt: Date(timeIntervalSince1970: 3_400),
    attributes: [.symlink]
)
let packageEntry = FileEntry(
    path: "/Applications/MacThing.app",
    name: "MacThing.app",
    parent: "/Applications",
    kind: .package,
    byteSize: nil,
    modifiedAt: Date(timeIntervalSince1970: 3_500),
    indexedAt: Date(timeIntervalSince1970: 3_500),
    attributes: [.directory, .package]
)
let extendedAttributeEntry = FileEntry(
    path: "/Users/me/Documents/ExtendedAttributes.bin",
    name: "ExtendedAttributes.bin",
    parent: "/Users/me/Documents",
    kind: .file,
    byteSize: 512,
    modifiedAt: Date(timeIntervalSince1970: 3_550),
    indexedAt: Date(timeIntervalSince1970: 3_550),
    attributes: [.file, .compressed, .encrypted, .notContentIndexed, .normal, .offline, .sparse, .temporary]
)
let attributeEntries = [
    hiddenEntry,
    readonlyEntry,
    systemEntry,
    symlinkEntry,
    packageEntry,
    extendedAttributeEntry,
    document
]
let audioEntry = FileEntry(
    path: "/Users/me/Music/Theme.m4a",
    name: "Theme.m4a",
    parent: "/Users/me/Music",
    kind: .file,
    byteSize: 4_096,
    modifiedAt: Date(timeIntervalSince1970: 3_600),
    indexedAt: Date(timeIntervalSince1970: 3_600)
)
let videoEntry = FileEntry(
    path: "/Users/me/Movies/Trailer.mov",
    name: "Trailer.mov",
    parent: "/Users/me/Movies",
    kind: .file,
    byteSize: 8_192,
    modifiedAt: Date(timeIntervalSince1970: 3_700),
    indexedAt: Date(timeIntervalSince1970: 3_700)
)
let archiveEntry = FileEntry(
    path: "/Users/me/Downloads/Backup.zip",
    name: "Backup.zip",
    parent: "/Users/me/Downloads",
    kind: .file,
    byteSize: 16_384,
    modifiedAt: Date(timeIntervalSince1970: 3_800),
    indexedAt: Date(timeIntervalSince1970: 3_800)
)
let executableScriptEntry = FileEntry(
    path: "/Users/me/bin/deploy.command",
    name: "deploy.command",
    parent: "/Users/me/bin",
    kind: .file,
    byteSize: 1_024,
    modifiedAt: Date(timeIntervalSince1970: 3_900),
    indexedAt: Date(timeIntervalSince1970: 3_900)
)
let categoryEntries = [
    photo,
    document,
    audioEntry,
    videoEntry,
    archiveEntry,
    executableScriptEntry,
    folder,
    symlinkEntry,
    packageEntry
]

expect(
    FileAttributes.inferred(kind: .file, name: ".env", path: "/Users/me/.env").contains(.hidden),
    "dot-prefixed files should infer hidden attributes"
)

expect(
    FileAttributes.inferred(kind: .file, name: "hosts", path: "/System/Library/hosts").contains(.system),
    "system paths should infer system attributes"
)

expect(
    Set(SearchEngine.search(query: "parent-name:$parent-name:", in: [document, childInFolder]).map(\.path)) ==
        Set([document.path, childInFolder.path]),
    "property substitution should support parent-name macros"
)

expect(
    SearchEngine.search(query: "stem:$kind:", in: [kindSubstitutionEntry, document]).map(\.path) == [kindSubstitutionEntry.path],
    "property substitution should support kind/type macros"
)

expect(
    SearchEngine.search(query: "name:$size:", in: [sizeSubstitutionEntry, document]).map(\.path) == [sizeSubstitutionEntry.path],
    "property substitution should support size macros"
)

expect(
    SearchEngine.search(query: "stem:$attributes: name:$name-len:", in: [attributeSubstitutionEntry, document]).map(\.path) ==
        [attributeSubstitutionEntry.path],
    "property substitution should support attribute and length macros"
)

expect(
    SearchEngine.search(query: "launch ext:jpg;jpeg", in: syntaxEntries).map(\.path) == [photo.path],
    "ext: should filter semicolon-delimited extension lists"
)

expect(
    Set(SearchEngine.search(query: "ext:", in: [hiddenEntry, symlinkEntry, folder, document]).map(\.path)) ==
        Set([hiddenEntry.path, symlinkEntry.path]),
    "empty ext: should match file-like entries with no extension"
)

expect(
    SearchEngine.search(query: "launch !folder:", in: syntaxEntries).map(\.path).contains(folder.path) == false,
    "!folder: should exclude folders"
)

expect(
    Set(SearchEngine.search(query: "(Launch | Empty) file:", in: syntaxEntries).map(\.path)) ==
        Set([photo.path, document.path, emptyFile.path, childInFolder.path]),
    "parenthesized OR groups should combine with implicit AND terms"
)

expect(
    Set(SearchEngine.search(query: "<Launch | Empty> file:", in: syntaxEntries).map(\.path)) ==
        Set([photo.path, document.path, emptyFile.path, childInFolder.path]),
    "Everything-style angle bracket OR groups should combine with implicit AND terms"
)

expect(
    SearchEngine.search(query: "Launch AND file:", in: syntaxEntries).map(\.path).contains(folder.path) == false,
    "explicit AND should combine adjacent search terms"
)

expect(
    Set(SearchEngine.search(query: "file:Launch", in: syntaxEntries).map(\.path)) ==
        Set([photo.path, document.path, childInFolder.path]),
    "file:<term> should match files only while applying the term"
)

expect(
    SearchEngine.search(query: "folder:Launch", in: syntaxEntries).map(\.path) == [folder.path],
    "folder:<term> should match folders only while applying the term"
)

expect(
    SearchEngine.search(query: "!(folder: | empty:) Launch", in: syntaxEntries).map(\.path).contains(folder.path) == false,
    "group negation should exclude entries matching any predicate in the group"
)

expect(
    SearchEngine.search(query: "folder:", in: syntaxEntries).map(\.path) == [folder.path],
    "folder: should match only folders"
)

expect(
    Set(SearchEngine.search(query: "everything:", in: [photo, document]).map(\.path)) ==
        Set([photo.path, document.path]),
    "everything: should match all files and folders"
)

expect(
    Set(SearchEngine.search(query: "nop:\"bookmark note\"", in: [photo, document]).map(\.path)) ==
        Set([photo.path, document.path]),
    "nop: should ignore its value and match all files and folders"
)

expect(
    SearchEngine.search(query: "nothing:", in: [photo, document]).isEmpty,
    "nothing: should match no files or folders"
)

let nothingResponse = SearchEngine.search(
    request: SearchRequest(query: "nothing:"),
    in: manyRecentEntries
)
expect(
    nothingResponse.entries.isEmpty &&
        nothingResponse.totalMatches == 0 &&
        nothingResponse.diagnostics?.searchedEntryCount == 0 &&
        nothingResponse.diagnostics?.builtFullContext == false,
    "statically impossible searches should return before scanning entries"
)

expect(
    SearchEngine.search(query: "Launch !nothing:", in: syntaxEntries).isEmpty == false,
    "!nothing: should behave as a no-op in AND searches"
)

let smallSizeEntry = FileEntry(
    path: "/Users/me/Sizes/Small.bin",
    name: "Small.bin",
    parent: "/Users/me/Sizes",
    kind: .file,
    byteSize: 50 * 1_024,
    modifiedAt: Date(timeIntervalSince1970: 4_000)
)
let mediumSizeEntry = FileEntry(
    path: "/Users/me/Sizes/Medium.bin",
    name: "Medium.bin",
    parent: "/Users/me/Sizes",
    kind: .file,
    byteSize: 500 * 1_024,
    modifiedAt: Date(timeIntervalSince1970: 4_010)
)
let hugeSizeEntry = FileEntry(
    path: "/Users/me/Sizes/Huge.bin",
    name: "Huge.bin",
    parent: "/Users/me/Sizes",
    kind: .file,
    byteSize: 32 * 1_024 * 1_024,
    modifiedAt: Date(timeIntervalSince1970: 4_020)
)
let giganticSizeEntry = FileEntry(
    path: "/Users/me/Sizes/Gigantic.bin",
    name: "Gigantic.bin",
    parent: "/Users/me/Sizes",
    kind: .file,
    byteSize: 200 * 1_024 * 1_024,
    modifiedAt: Date(timeIntervalSince1970: 4_030)
)

expect(
    SearchEngine.search(query: "size:>1mb", in: syntaxEntries).map(\.path) == [photo.path],
    "size: should understand byte units and comparisons"
)

expect(
    SearchEngine.search(query: "sz:>1mb", in: syntaxEntries).map(\.path) == [photo.path],
    "sz: should alias size:"
)

expect(
    SearchEngine.search(query: "size:==2000", in: [photo, document, emptyFile]).map(\.path) == [document.path],
    "size: should support explicit equality comparisons"
)

expect(
    Set(SearchEngine.search(query: "size:!=0", in: [photo, document, emptyFile]).map(\.path)) ==
        Set([photo.path, document.path]),
    "size: should support not-equal comparisons"
)

expect(
    Set(SearchEngine.search(query: "size:!0", in: [photo, document, emptyFile]).map(\.path)) ==
        Set([photo.path, document.path]),
    "size: should support Everything-style ! not-equal shorthand"
)

expect(
    Set(SearchEngine.search(query: "size:1kb..3mb", in: syntaxEntries).map(\.path)) ==
        Set([photo.path, document.path]),
    "size: should understand inclusive byte-size ranges"
)

expect(
    Set(SearchEngine.search(query: "size:0;2000", in: [photo, document, emptyFile]).map(\.path)) ==
        Set([document.path, emptyFile.path]),
    "function values should support semicolon OR lists"
)

expect(
    SearchEngine.search(query: "size:empty", in: [emptyFile, document, folder]).map(\.path) == [emptyFile.path],
    "size:empty should match zero-byte entries"
)

expect(
    SearchEngine.search(query: "size:tiny", in: [emptyFile, document, smallSizeEntry]).map(\.path) == [document.path],
    "size:tiny should match files from 1 byte through 10 KB"
)

expect(
    SearchEngine.search(query: "sz:small", in: [document, smallSizeEntry, mediumSizeEntry]).map(\.path) == [smallSizeEntry.path],
    "sz:small should match files above 10 KB through 100 KB"
)

expect(
    SearchEngine.search(query: "size:medium", in: [smallSizeEntry, mediumSizeEntry, photo]).map(\.path) == [mediumSizeEntry.path],
    "size:medium should match files above 100 KB through 1 MB"
)

expect(
    SearchEngine.search(query: "size:large", in: [mediumSizeEntry, photo, hugeSizeEntry]).map(\.path) == [photo.path],
    "size:large should match files above 1 MB through 16 MB"
)

expect(
    SearchEngine.search(query: "size:huge", in: [photo, hugeSizeEntry, giganticSizeEntry]).map(\.path) == [hugeSizeEntry.path],
    "size:huge should match files above 16 MB through 128 MB"
)

expect(
    SearchEngine.search(query: "size:gigantic", in: [hugeSizeEntry, giganticSizeEntry]).map(\.path) == [giganticSizeEntry.path],
    "size:gigantic should match files above 128 MB"
)

expect(
    SearchEngine.search(query: "size:unknown", in: [folder, document]).map(\.path) == [folder.path],
    "size:unknown should match entries without a known byte size"
)

expect(
    SearchEngine.search(query: "<Launch file:> | size:>1mb", in: syntaxEntries).map(\.path).contains(photo.path),
    "angle bracket grouping should not break comparison operators inside function values"
)

expect(
    SearchEngine.search(query: "regex:^Launch", in: syntaxEntries).count == 3,
    "regex: should match result names"
)

expect(
    SearchEngine.search(query: "stem:Notes", in: syntaxEntries).map(\.path) == [document.path],
    "stem: should match the filename stem without the extension"
)

expect(
    SearchEngine.search(query: "basename:Notes", in: syntaxEntries).map(\.path) == [document.path],
    "basename: should alias filename searches"
)

expect(
    Set(SearchEngine.search(query: "stem:Launch;Empty", in: syntaxEntries).map(\.path)) ==
        Set([photo.path, document.path, folder.path, emptyFile.path]),
    "stem: should support semicolon OR lists"
)

expect(
    SearchEngine.search(query: "stem:JPG", in: [photo]).isEmpty,
    "stem: should not match only the file extension"
)

expect(
    Set(SearchEngine.search(query: "path-part:Documents", in: syntaxEntries).map(\.path)) ==
        Set([document.path, folder.path, emptyFile.path, childInFolder.path]),
    "path-part: should match individual path components"
)

expect(
    Set(SearchEngine.search(query: "path-part:/Users/me/Documents", in: syntaxEntries).map(\.path)) ==
        Set([document.path, folder.path, emptyFile.path, childInFolder.path]),
    "path-part: should match the basename-excluded parent path"
)

expect(
    SearchEngine.search(query: "path-part:Doc*", in: syntaxEntries).map(\.path).contains(document.path),
    "path-part: should support wildcard component matching"
)

expect(
    SearchEngine.search(query: "location:Pictures", in: syntaxEntries).map(\.path) == [photo.path],
    "location: should alias path-part:"
)

expect(
    SearchEngine.search(query: "pp:Pictures", in: syntaxEntries).map(\.path) == [photo.path],
    "pp: should alias path-part:"
)

expect(
    Set(SearchEngine.search(query: "path-list:/Users/me/Pictures/Launch.JPG;/Users/me/Documents/Launch", in: syntaxEntries).map(\.path)) ==
        Set([photo.path, folder.path]),
    "path-list: should match semicolon-delimited full paths exactly"
)

expect(
    SearchEngine.search(query: "full-path-list:/Users/me/Documents/Launch", in: syntaxEntries).map(\.path) == [folder.path],
    "full-path-list: should alias exact full path list searches"
)

expect(
    SearchEngine.search(query: "path-list:/Users/me/Documents", in: syntaxEntries).isEmpty,
    "path-list: should not match partial path prefixes"
)

expect(
    SearchEngine.search(query: "empty:", in: syntaxEntries).map(\.path) == [emptyFile.path],
    "empty: should match zero-byte files and folders without indexed children"
)

expect(
    SearchEngine.search(query: "empty:0", in: [emptyFile, document]).map(\.path) == [document.path],
    "empty:0 should match non-empty entries"
)

expect(
    Set(SearchEngine.search(query: "dupe:", in: syntaxEntries).map(\.path)) == Set([duplicateA.path, duplicateB.path]),
    "dupe: should match entries with duplicate names"
)

let duplicateDiagnostics = SearchEngine.search(
    request: SearchRequest(query: "dupe:", limit: 20),
    in: syntaxEntries
)
expect(
    duplicateDiagnostics.diagnostics?.builtFullContext == true,
    "duplicate searches should still build full search context"
)

expect(
    Set(SearchEngine.search(query: "name-frequency:2", in: [duplicateA, duplicateB, document]).map(\.path)) ==
        Set([duplicateA.path, duplicateB.path]),
    "name-frequency: should compare the frequency of each filename"
)

expect(
    SearchEngine.search(query: "dupe:0", in: [document, duplicateA, duplicateB]).map(\.path) == [document.path],
    "dupe:0 should match entries with unique names"
)

expect(
    Set(SearchEngine.search(query: "extension-frequency:3", in: [document, duplicateA, duplicateB, photo, folder]).map(\.path)) ==
        Set([document.path, duplicateA.path, duplicateB.path]),
    "extension-frequency: should compare file extension frequencies"
)

expect(
    Set(SearchEngine.search(query: "path-dupe:", in: syntaxEntries).map(\.path)) ==
        Set([document.path, folder.path, emptyFile.path]),
    "path-dupe: should match entries whose basename-excluded path is duplicated"
)

expect(
    SearchEngine.search(query: "path-dupe:false", in: [document, folder, childInFolder]).map(\.path) == [childInFolder.path],
    "path-dupe:false should match entries with a unique path part"
)

expect(
    Set(SearchEngine.search(query: "namepartdupe:", in: duplicateMetricEntries).map(\.path)) ==
        Set([sameNamePartText.path, sameNamePartMarkdown.path]),
    "namepartdupe: should match entries with duplicate filename stems"
)

expect(
    Set(SearchEngine.search(query: "sizedupe:", in: duplicateMetricEntries).map(\.path)) ==
        Set([sameNamePartText.path, sameNamePartMarkdown.path]),
    "sizedupe: should match entries with duplicate byte sizes"
)

expect(
    SearchEngine.search(query: "sizedupe:0", in: duplicateMetricEntries).map(\.path) == [uniqueDuplicateMetricEntry.path],
    "sizedupe:0 should match entries with unique byte sizes"
)

expect(
    Set(SearchEngine.search(query: "dcdupe:", in: duplicateMetricEntries).map(\.path)) ==
        Set([sameNamePartText.path, sameNamePartMarkdown.path]),
    "dcdupe: should match entries with duplicate created dates"
)

expect(
    Set(SearchEngine.search(query: "dmdupe:", in: duplicateMetricEntries).map(\.path)) ==
        Set([sameNamePartText.path, sameNamePartMarkdown.path]),
    "dmdupe: should match entries with duplicate modified dates"
)

expect(
    Set(SearchEngine.search(query: "dadupe:", in: duplicateMetricEntries).map(\.path)) ==
        Set([sameNamePartText.path, sameNamePartMarkdown.path]),
    "dadupe: should match entries with duplicate accessed dates"
)

expect(
    Set(SearchEngine.search(query: "attribdupe:", in: duplicateMetricEntries).map(\.path)) ==
        Set([sameNamePartText.path, sameNamePartMarkdown.path]),
    "attribdupe: should match entries with duplicate attributes"
)

expect(
    SearchEngine.search(query: "len:>10", in: [folder, document]).map(\.path) == [document.path],
    "len: should compare filename length"
)

expect(
    Set(SearchEngine.search(query: "len:5..10", in: [folder, emptyFile, document]).map(\.path)) ==
        Set([folder.path, emptyFile.path]),
    "len: should understand inclusive filename-length ranges"
)

expect(
    SearchEngine.search(query: "chars:\(emojiNameEntry.name.count)", in: [emojiNameEntry, document]).map(\.path) == [emojiNameEntry.path],
    "chars: should compare filename character counts"
)

expect(
    emojiNameEntry.name.count != emojiNameEntry.name.utf16.count,
    "emoji length fixtures should distinguish character and UTF-16 lengths"
)

expect(
    SearchEngine.search(query: "len:\(emojiNameEntry.name.utf16.count)", in: [emojiNameEntry, document]).map(\.path) == [emojiNameEntry.path],
    "len: should compare filename UTF-16 code unit length"
)

expect(
    SearchEngine.search(query: "filename-len:\(document.path.utf16.count)", in: [folder, document]).map(\.path) == [document.path],
    "filename-len: should compare full path and filename UTF-16 length"
)

expect(
    SearchEngine.search(query: "basename-length:\(folder.name.utf16.count)", in: [folder, document]).map(\.path) == [folder.path],
    "basename-length: should compare basename UTF-16 length"
)

expect(
    Set(SearchEngine.search(query: "stem-len:6", in: [photo, folder, document]).map(\.path)) ==
        Set([photo.path, folder.path]),
    "stem-len: should compare filename stem UTF-16 lengths"
)

expect(
    utf8NameEntry.name.count != utf8NameEntry.name.utf8.count,
    "UTF-8 length fixtures should use a multibyte filename"
)

expect(
    SearchEngine.search(query: "utf8-len:\(utf8NameEntry.name.utf8.count)", in: [utf8NameEntry, document]).map(\.path) == [utf8NameEntry.path],
    "utf8-len: should compare filename UTF-8 byte lengths"
)

expect(
    SearchEngine.search(query: "name-len-in-utf8-bytes:\(utf8NameEntry.name.utf8.count)", in: [utf8NameEntry, document]).map(\.path) == [utf8NameEntry.path],
    "name-len-in-utf8-bytes: should alias utf8-len:"
)

expect(
    SearchEngine.search(query: "full-path-utf8-byte-length:\(utf8NameEntry.path.utf8.count)", in: [utf8NameEntry, document]).map(\.path) == [utf8NameEntry.path],
    "full-path-utf8-byte-length: should compare full path UTF-8 byte lengths"
)

expect(
    SearchEngine.search(query: "path-len:\(photo.path.utf16.count)", in: [photo, document]).map(\.path) == [photo.path],
    "path-len: should compare full path UTF-16 lengths"
)

expect(
    SearchEngine.search(query: "path-part-len:\(photo.parent.utf16.count)", in: [photo, document]).map(\.path) == [photo.path],
    "path-part-len: should compare basename-excluded parent path UTF-16 lengths"
)

expect(
    SearchEngine.search(query: "location-len:\(photo.parent.utf16.count)", in: [photo, document]).map(\.path) == [photo.path],
    "location-len: should alias path-part-len:"
)

expect(
    SearchEngine.search(query: "ext-len:3", in: [photo, document, folder]).map(\.path) == [photo.path],
    "ext-len: should compare file extension lengths"
)

expect(
    SearchEngine.search(query: "childcount:>0", in: syntaxEntries).map(\.path) == [folder.path],
    "childcount: should compare direct indexed children"
)

expect(
    SearchEngine.search(query: "child:", in: syntaxEntries).map(\.path) == [folder.path],
    "child: with an empty value should match containers that have direct children"
)

expect(
    SearchEngine.search(query: "childfilecount:1", in: syntaxEntries).map(\.path) == [folder.path],
    "childfilecount: should compare direct file children"
)

expect(
    SearchEngine.search(query: "child-file-count:1", in: syntaxEntries).map(\.path) == [folder.path],
    "dashed child count aliases should compare direct file children"
)

expect(
    SearchEngine.search(query: "childfoldercount:0", in: [folder, childInFolder]).map(\.path) == [folder.path],
    "childfoldercount: should compare direct folder children"
)

expect(
    SearchEngine.search(
        query: "total-child-size:12",
        in: [folder, childInFolder, childFolderInFolder, nestedGrandchild]
    ).map(\.path) == [folder.path],
    "total-child-size: should sum direct file children only"
)

expect(
    SearchEngine.search(
        query: "total-child-size:1000",
        in: [folder, childInFolder, childFolderInFolder, nestedGrandchild]
    ).map(\.path) == [childFolderInFolder.path],
    "total-child-size: should not include descendant files through subfolders"
)

expect(
    SearchEngine.search(query: "child:Child", in: syntaxEntries).map(\.path) == [folder.path],
    "child: should match folders that contain a matching direct child name"
)

expect(
    SearchEngine.search(query: "child-file:Child", in: syntaxEntries).map(\.path) == [folder.path],
    "child-file: should match folders that contain a matching direct file child"
)

expect(
    SearchEngine.search(query: "child-folder:Nested", in: [folder, childFolderInFolder]).map(\.path) == [folder.path],
    "child-folder: should match folders that contain a matching direct folder child"
)

expect(
    SearchEngine.search(query: "child-attr:h", in: [folder, hiddenChildInFolder]).map(\.path) == [folder.path],
    "child-attr: should match folders with a direct child carrying matching attributes"
)

expect(
    SearchEngine.search(query: "child-file-attr:h", in: [folder, hiddenChildInFolder, childFolderInFolder]).map(\.path) == [folder.path],
    "child-file-attr: should match direct file children only"
)

expect(
    SearchEngine.search(query: "child-folder-attr:d", in: [folder, hiddenChildInFolder, childFolderInFolder]).map(\.path) == [folder.path],
    "child-folder-attr: should match direct folder children only"
)

expect(
    SearchEngine.search(
        query: "child-dc:2024-05-01",
        in: [folder, childMetadataFile]
    ).map(\.path) == [folder.path],
    "child-dc: should match folders with a direct child created on the specified date"
)

expect(
    SearchEngine.search(
        query: "child-file-date-accessed:2024-05-03",
        in: [folder, childMetadataFile, childMetadataFolder]
    ).map(\.path) == [folder.path],
    "child-file-date-accessed: should restrict child date checks to files"
)

expect(
    SearchEngine.search(
        query: "child-file-dm:2024-05-02",
        in: [folder, childMetadataFile, childMetadataFolder]
    ).map(\.path) == [folder.path],
    "child-file-dm: should match folders with a direct file child modified on the specified date"
)

expect(
    SearchEngine.search(
        query: "child-folder-date-created:2024-06-01",
        in: [folder, childMetadataFile, childMetadataFolder]
    ).map(\.path) == [folder.path],
    "child-folder-date-created: should restrict child creation date checks to folders"
)

expect(
    SearchEngine.search(
        query: "child-rc:2024-05-04",
        in: [folder, childMetadataFile]
    ).map(\.path) == [folder.path],
    "child-rc: should match folders with a direct child recently changed on the specified date"
)

expect(
    SearchEngine.search(
        query: "child-date-run:2024-05-05",
        in: [folder, childMetadataFile]
    ).map(\.path) == [folder.path],
    "child-date-run: should match folders with a direct child last run on the specified date"
)

expect(
    SearchEngine.search(
        query: "child-file-run-count:7",
        in: [folder, childMetadataFile, childMetadataFolder]
    ).map(\.path) == [folder.path],
    "child-file-run-count: should restrict child run count checks to files"
)

expect(
    SearchEngine.search(
        query: "child-file-size:2048",
        in: [folder, childMetadataFile, childMetadataFolder]
    ).map(\.path) == [folder.path],
    "child-file-size: should match direct file children with the specified byte size"
)

expect(
    SearchEngine.search(
        query: "child-folder-size:4096",
        in: [folder, childMetadataFile, childMetadataFolder]
    ).map(\.path) == [folder.path],
    "child-folder-size: should match direct folder children with the specified byte size"
)

expect(
    SearchEngine.search(
        query: "child-file-list:Metadata.bin;Missing.bin",
        in: [folder, childMetadataFile]
    ).map(\.path) == [folder.path],
    "child-file-list: should match semicolon-delimited direct child names exactly"
)

expect(
    SearchEngine.search(
        query: "child-file-list:/Users/me/Documents/Launch/MetadataFolder",
        in: [folder, childMetadataFolder]
    ).map(\.path) == [folder.path],
    "child-file-list: should match direct child full paths exactly when a separator is present"
)

expect(
    SearchEngine.search(
        query: "child-file-list:Metadata",
        in: [folder, childMetadataFile]
    ).isEmpty,
    "child-file-list: should not perform partial child filename matching"
)

expect(
    Set(SearchEngine.search(
        query: "descendant:Grandchild",
        in: [folder, childInFolder, childFolderInFolder, nestedGrandchild]
    ).map(\.path)) == Set([folder.path, childFolderInFolder.path]),
    "descendant: should match folders containing matching children or grandchildren"
)

expect(
    Set(SearchEngine.search(
        query: "descendant-file:Grandchild",
        in: [folder, childInFolder, childFolderInFolder, nestedGrandchild]
    ).map(\.path)) == Set([folder.path, childFolderInFolder.path]),
    "descendant-file: should match folders containing matching file descendants"
)

expect(
    SearchEngine.search(
        query: "descendant-folder:Nested",
        in: [folder, childFolderInFolder, nestedGrandchild]
    ).map(\.path) == [folder.path],
    "descendant-folder: should match folders containing matching folder descendants"
)

expect(
    SearchEngine.search(
        query: "descendant-count:3",
        in: [folder, childInFolder, childFolderInFolder, nestedGrandchild]
    ).map(\.path) == [folder.path],
    "descendant-count: should count children and grandchildren"
)

expect(
    SearchEngine.search(
        query: "descendant-file-count:2",
        in: [folder, childInFolder, childFolderInFolder, nestedGrandchild]
    ).map(\.path) == [folder.path],
    "descendant-file-count: should count file descendants only"
)

expect(
    SearchEngine.search(
        query: "descendant-folder-count:1",
        in: [folder, childInFolder, childFolderInFolder, nestedGrandchild]
    ).map(\.path) == [folder.path],
    "descendant-folder-count: should count folder descendants only"
)

expect(
    SearchEngine.search(query: "child:*.txt", in: syntaxEntries).map(\.path) == [folder.path],
    "child: should support wildcard child-name matching"
)

expect(
    SearchEngine.search(query: "path:child:Documents/Launch/Child", in: syntaxEntries).map(\.path) == [folder.path],
    "path:child: should allow child path matching"
)

expect(
    SearchEngine.search(query: "parent-child:Child", in: syntaxEntries).map(\.path) == [childInFolder.path],
    "parent-child: should match the entry itself as one of its parent's children"
)

expect(
    SearchEngine.search(query: "parent-child-file:Child", in: syntaxEntries).map(\.path) == [childInFolder.path],
    "parent-child-file: should restrict the matching parent child to files"
)

expect(
    Set(SearchEngine.search(query: "parent-child-folder:Launch", in: syntaxEntries).map(\.path)) ==
        Set([document.path, folder.path, emptyFile.path]),
    "parent-child-folder: should match entries whose parent has a matching folder child"
)

expect(
    Set(SearchEngine.search(query: "sibling:Empty", in: syntaxEntries).map(\.path)) ==
        Set([document.path, folder.path]),
    "sibling: should match entries with a matching sibling name"
)

expect(
    Set(SearchEngine.search(query: "sibling-file:Empty", in: syntaxEntries).map(\.path)) ==
        Set([document.path, folder.path]),
    "sibling-file: should match entries with a matching file sibling"
)

expect(
    Set(SearchEngine.search(query: "sibling-folder:Launch", in: syntaxEntries).map(\.path)) ==
        Set([document.path, emptyFile.path]),
    "sibling-folder: should match entries with a matching folder sibling"
)

expect(
    Set(SearchEngine.search(query: "sibling:", in: syntaxEntries).map(\.path)) ==
        Set([document.path, folder.path, emptyFile.path]),
    "sibling: with an empty value should match entries that have any sibling"
)

expect(
    Set(SearchEngine.search(query: "sibling-count:2", in: syntaxEntries).map(\.path)) ==
        Set([document.path, folder.path, emptyFile.path]),
    "sibling-count: should compare total sibling counts"
)

expect(
    SearchEngine.search(query: "sibling-file-count:2", in: syntaxEntries).map(\.path) == [folder.path],
    "sibling-file-count: should compare file sibling counts"
)

expect(
    Set(SearchEngine.search(query: "sibling-folder-count:1", in: syntaxEntries).map(\.path)) ==
        Set([document.path, emptyFile.path]),
    "sibling-folder-count: should compare folder sibling counts"
)

expect(
    Set(SearchEngine.search(query: "parent:/Users/me/Documents", in: syntaxEntries).map(\.path)) ==
        Set([document.path, folder.path, emptyFile.path]),
    "parent: should match only direct children of the specified absolute parent path"
)

expect(
    Set(SearchEngine.search(query: "parent-name:Documents", in: syntaxEntries).map(\.path)) ==
        Set([document.path, folder.path, emptyFile.path]),
    "parent-name: should match entries by direct parent folder name"
)

expect(
    Set(SearchEngine.search(query: "parent-path:/Users/me/Doc", in: syntaxEntries).map(\.path)) ==
        Set([document.path, folder.path, emptyFile.path, childInFolder.path]),
    "parent-path: should match entries by direct parent path text"
)

expect(
    Set(SearchEngine.search(query: "parent-full-path:/Users/me/Doc", in: syntaxEntries).map(\.path)) ==
        Set([document.path, folder.path, emptyFile.path, childInFolder.path]),
    "parent-full-path: should alias parent path text matching"
)

expect(
    Set(SearchEngine.search(query: "ancestor:/Users/me/Documents", in: syntaxEntries).map(\.path)) ==
        Set([document.path, folder.path, emptyFile.path, childInFolder.path]),
    "ancestor: should match direct and nested descendants of an absolute ancestor path"
)

expect(
    Set(SearchEngine.search(query: "ancestor-name:Documents", in: syntaxEntries).map(\.path)) ==
        Set([document.path, folder.path, emptyFile.path, childInFolder.path]),
    "ancestor-name: should match entries by any ancestor folder name"
)

expect(
    SearchEngine.search(query: "ancestor:Launch", in: syntaxEntries).map(\.path) == [childInFolder.path],
    "relative ancestor: values should match ancestor folder names"
)

expect(
    SearchEngine.search(query: "parent-sibling:Empty", in: syntaxEntries).map(\.path) == [childInFolder.path],
    "parent-sibling: should match entries whose parent has a matching sibling"
)

expect(
    SearchEngine.search(query: "parent-sibling-file:Empty", in: syntaxEntries).map(\.path) == [childInFolder.path],
    "parent-sibling-file: should match entries whose parent has a matching file sibling"
)

expect(
    SearchEngine.search(query: "parent-sibling-folder:Archive", in: [document, folder, emptyFile, childInFolder, auntFolder]).map(\.path) == [childInFolder.path],
    "parent-sibling-folder: should match entries whose parent has a matching folder sibling"
)

expect(
    SearchEngine.search(query: "ancestor-sibling:Empty", in: syntaxEntries).map(\.path) == [childInFolder.path],
    "ancestor-sibling: should match entries with an ancestor that has a matching sibling"
)

expect(
    Set(SearchEngine.search(
        query: "ancestor-attr:d",
        in: [folder, childFolderInFolder, nestedGrandchild]
    ).map(\.path)) == Set([childFolderInFolder.path, nestedGrandchild.path]),
    "ancestor-attr: should match entries with an indexed parent or grandparent carrying attributes"
)

expect(
    SearchEngine.search(
        query: "ancestor-attribute:h",
        in: [hiddenAncestorFolder, childUnderHiddenAncestor]
    ).map(\.path) == [childUnderHiddenAncestor.path],
    "ancestor-attribute: should alias ancestor-attr:"
)

expect(
    Set(SearchEngine.search(
        query: "ancestor-child-file:Child",
        in: [folder, childInFolder, childFolderInFolder, nestedGrandchild]
    ).map(\.path)) == Set([childInFolder.path, childFolderInFolder.path, nestedGrandchild.path]),
    "ancestor-child-file: should match entries whose ancestor has a matching direct file child"
)

expect(
    Set(SearchEngine.search(
        query: "ancestor-child-folder:Nested",
        in: [folder, childInFolder, childFolderInFolder, nestedGrandchild]
    ).map(\.path)) == Set([childInFolder.path, childFolderInFolder.path, nestedGrandchild.path]),
    "ancestor-child-folder: should match entries whose ancestor has a matching direct folder child"
)

expect(
    Set(SearchEngine.search(query: "infolder:/Users/me/Documents", in: syntaxEntries).map(\.path)) ==
        Set([document.path, folder.path, emptyFile.path]),
    "infolder: should match direct children of the specified parent path"
)

expect(
    Set(SearchEngine.search(query: "nosubfolders:/Users/me/Documents", in: syntaxEntries).map(\.path)) ==
        Set([document.path, folder.path, emptyFile.path]),
    "nosubfolders: should match direct children of the specified parent path"
)

expect(
    Set(SearchEngine.search(query: "parent+0:/Users/me/Documents", in: syntaxEntries).map(\.path)) ==
        Set([document.path, folder.path, emptyFile.path]),
    "parent+0: should match the same direct children as parent:"
)

expect(
    Set(SearchEngine.search(
        query: "parent+1:/Users/me/Documents",
        in: [document, folder, emptyFile, childInFolder, childFolderInFolder, nestedGrandchild]
    ).map(\.path)) == Set([document.path, folder.path, emptyFile.path, childInFolder.path, childFolderInFolder.path]),
    "parent+1: should include direct children and one level deeper"
)

expect(
    Set(SearchEngine.search(
        query: "parent+2:/Users/me/Documents",
        in: [document, folder, emptyFile, childInFolder, childFolderInFolder, nestedGrandchild]
    ).map(\.path)) == Set([document.path, folder.path, emptyFile.path, childInFolder.path, childFolderInFolder.path, nestedGrandchild.path]),
    "parent+2: should include direct children and up to two levels deeper"
)

expect(
    Set(SearchEngine.search(
        query: "parent-depth1:/Users/me/Documents",
        in: [document, folder, emptyFile, childInFolder, childFolderInFolder, nestedGrandchild]
    ).map(\.path)) == Set([childInFolder.path, childFolderInFolder.path]),
    "parent-depth1: should match entries exactly one level deeper than the specified parent"
)

expect(
    SearchEngine.search(
        query: "parent-depth2:/Users/me/Documents",
        in: [document, folder, emptyFile, childInFolder, childFolderInFolder, nestedGrandchild]
    ).map(\.path) == [nestedGrandchild.path],
    "parent-depth2: should match entries exactly two levels deeper than the specified parent"
)

expect(
    SearchEngine.search(
        query: "parent-dc:2024-02-03",
        in: [metadataParentFolder, metadataParentChild]
    ).map(\.path) == [metadataParentChild.path],
    "parent-dc: should match entries whose indexed parent has the specified creation date"
)

expect(
    SearchEngine.search(
        query: "parent-date-modified:2024-03-04",
        in: [metadataParentFolder, metadataParentChild]
    ).map(\.path) == [metadataParentChild.path],
    "parent-date-modified: should match entries whose indexed parent has the specified modified date"
)

expect(
    SearchEngine.search(
        query: "parent-size:==4096",
        in: [metadataParentFolder, metadataParentChild]
    ).map(\.path) == [metadataParentChild.path],
    "parent-size: should compare the indexed parent folder size"
)

expect(
    Set(SearchEngine.search(query: "parent:Documents", in: syntaxEntries).map(\.path)) ==
        Set([document.path, folder.path, emptyFile.path]),
    "relative parent: values should match direct parent folder names without including grandchildren"
)

expect(
    SearchEngine.search(query: "parents:3", in: [document, childInFolder]).map(\.path) == [document.path],
    "parents: should compare parent folder counts without counting the filename"
)

expect(
    SearchEngine.search(query: "parent-count:4", in: [document, childInFolder]).map(\.path) == [childInFolder.path],
    "parent-count: should alias depth:"
)

expect(
    Set(SearchEngine.search(query: "startwith:Launch", in: syntaxEntries).map(\.path)) ==
        Set([photo.path, document.path, folder.path]),
    "startwith: should match filename prefixes"
)

expect(
    Set(SearchEngine.search(query: "start-with:Launch", in: syntaxEntries).map(\.path)) ==
        Set([photo.path, document.path, folder.path]),
    "dashed function names should match filename prefixes"
)

expect(
    SearchEngine.search(query: "endwith:.jpg", in: syntaxEntries).map(\.path) == [photo.path],
    "endwith: should match filename suffixes with normal matching options"
)

expect(
    SearchEngine.search(query: "end-with:.jpg", in: syntaxEntries).map(\.path) == [photo.path],
    "dashed function names should match filename suffixes"
)

expect(
    SearchEngine.search(query: "exact:Launch.JPG", in: syntaxEntries).map(\.path) == [photo.path],
    "exact: should require a full filename match"
)

expect(
    SearchEngine.search(query: "whole-filename:Launch.JPG", in: syntaxEntries).map(\.path) == [photo.path],
    "dashed modifier names should require a full filename match"
)

expect(
    SearchEngine.search(query: "frn:12345", in: [identitySearchEntry, otherIdentitySearchEntry]).map(\.path) == [identitySearchEntry.path],
    "frn: should match filesystem identity file IDs"
)

expect(
    SearchEngine.search(query: "frn:678:12345", in: [identitySearchEntry, otherIdentitySearchEntry]).map(\.path) == [identitySearchEntry.path],
    "frn: should match volume-qualified filesystem identity keys"
)

expect(
    Set(SearchEngine.search(query: "frn:12345;999", in: [identitySearchEntry, otherIdentitySearchEntry]).map(\.path)) ==
        Set([identitySearchEntry.path, otherIdentitySearchEntry.path]),
    "frn: should support semicolon-delimited identity lists"
)

expect(
    Set(SearchEngine.search(query: "frn:", in: [identitySearchEntry, otherIdentitySearchEntry, document]).map(\.path)) ==
        Set([identitySearchEntry.path, otherIdentitySearchEntry.path]),
    "empty frn: should match entries with known filesystem identity"
)

let fsiEntries = [fsiSecondaryEntry, fsiPrimaryEntry, fsiPrimarySiblingEntry]
expect(
    Set(SearchEngine.search(query: "fsi:0", in: fsiEntries).map(\.path)) ==
        Set([fsiPrimaryEntry.path, fsiPrimarySiblingEntry.path]),
    "fsi: should match entries in the zero-based internal file system index"
)

expect(
    SearchEngine.search(query: "fsi:1", in: fsiEntries).map(\.path) == [fsiSecondaryEntry.path],
    "fsi: should match later internal file system indexes"
)

expect(
    SearchEngine.search(query: "fsi:>=1", in: fsiEntries).map(\.path) == [fsiSecondaryEntry.path],
    "fsi: should support comparison filters"
)

let mediaTaggedEntries = [mediaTaggedEntry, otherMediaTaggedEntry, document]
expect(
    SearchEngine.search(query: "title:Launch", in: mediaTaggedEntries).map(\.path) == [mediaTaggedEntry.path],
    "title: should match media title metadata"
)

expect(
    SearchEngine.search(query: "artist:Ensemble", in: mediaTaggedEntries).map(\.path) == [mediaTaggedEntry.path],
    "artist: should match media artist metadata"
)

expect(
    SearchEngine.search(query: "album:MacThing", in: mediaTaggedEntries).map(\.path) == [mediaTaggedEntry.path],
    "album: should match media album metadata"
)

expect(
    SearchEngine.search(query: "comment:Everything-style", in: mediaTaggedEntries).map(\.path) == [mediaTaggedEntry.path],
    "comment: should match media comment metadata"
)

expect(
    SearchEngine.search(query: "genre:Soundtrack", in: mediaTaggedEntries).map(\.path) == [mediaTaggedEntry.path],
    "genre: should match media genre metadata"
)

expect(
    SearchEngine.search(query: "track:7", in: mediaTaggedEntries).map(\.path) == [mediaTaggedEntry.path],
    "track: should match media track metadata"
)

expect(
    SearchEngine.search(query: "track:>5", in: mediaTaggedEntries).map(\.path) == [mediaTaggedEntry.path],
    "track: should support comparison filters"
)

expect(
    SearchEngine.search(query: "year:2026", in: mediaTaggedEntries).map(\.path) == [mediaTaggedEntry.path],
    "year: should match media year metadata"
)

expect(
    SearchEngine.search(query: "year:>=2020", in: mediaTaggedEntries).map(\.path) == [mediaTaggedEntry.path],
    "year: should support comparison filters"
)

expect(
    SearchEngine.search(
        request: SearchRequest(query: "file:", sortField: .artist, sortDirection: .ascending),
        in: [mediaTaggedEntry, otherMediaTaggedEntry]
    ).entries.map(\.path) == [otherMediaTaggedEntry.path, mediaTaggedEntry.path],
    "artist sorting should use media artist metadata"
)

expect(
    SearchEngine.search(
        request: SearchRequest(query: "file:", sortField: .track, sortDirection: .descending),
        in: [mediaTaggedEntry, otherMediaTaggedEntry]
    ).entries.map(\.path) == [mediaTaggedEntry.path, otherMediaTaggedEntry.path],
    "track sorting should use media track metadata"
)

expect(
    SearchEngine.search(
        request: SearchRequest(query: "sort:year descending: file:"),
        in: [mediaTaggedEntry, otherMediaTaggedEntry]
    ).entries.map(\.path) == [mediaTaggedEntry.path, otherMediaTaggedEntry.path],
    "sort:year should use media year metadata"
)

expect(
    SearchEngine.search(query: "attrib:h", in: attributeEntries).map(\.path) == [hiddenEntry.path],
    "attrib:h should match hidden entries"
)

expect(
    SearchEngine.search(query: "attribute:h", in: attributeEntries).map(\.path) == [hiddenEntry.path],
    "attribute:h should alias attrib:h"
)

expect(
    SearchEngine.search(query: "hidden:", in: attributeEntries).map(\.path) == [hiddenEntry.path],
    "hidden: should match hidden entries"
)

expect(
    SearchEngine.search(query: "hidden:0", in: [hiddenEntry, document]).map(\.path) == [document.path],
    "hidden:0 should exclude hidden entries"
)

expect(
    SearchEngine.search(query: "attrib:!h", in: [hiddenEntry, readonlyEntry]).map(\.path) == [readonlyEntry.path],
    "attrib:!h should exclude hidden entries"
)

expect(
    SearchEngine.search(query: "attrib:r", in: attributeEntries).map(\.path) == [readonlyEntry.path],
    "attrib:r should match readonly entries"
)

expect(
    SearchEngine.search(query: "readonly:", in: attributeEntries).map(\.path) == [readonlyEntry.path],
    "readonly: should match readonly entries"
)

expect(
    SearchEngine.search(query: "read-only:", in: attributeEntries).map(\.path) == [readonlyEntry.path],
    "dashed attribute aliases should match readonly entries"
)

expect(
    SearchEngine.search(query: "system:", in: attributeEntries).map(\.path) == [systemEntry.path],
    "system: should match system entries"
)

expect(
    SearchEngine.search(query: "symlink:", in: attributeEntries).map(\.path) == [symlinkEntry.path],
    "symlink: should match symlink entries"
)

expect(
    SearchEngine.search(query: "package:", in: attributeEntries).map(\.path) == [packageEntry.path],
    "package: should match package entries"
)

expect(
    SearchEngine.search(query: "attrib:dp", in: attributeEntries).map(\.path).isEmpty,
    "attrib:p should use Everything's sparse-file constant, not Mac package metadata"
)

expect(
    SearchEngine.search(query: "attrib:cei", in: attributeEntries).map(\.path) == [extendedAttributeEntry.path],
    "attrib: should support compressed, encrypted, and not-indexed constants"
)

expect(
    SearchEngine.search(query: "attrib:nop", in: attributeEntries).map(\.path) == [extendedAttributeEntry.path],
    "attrib: should support normal, offline, and sparse constants"
)

expect(
    SearchEngine.search(query: "attrib:no-t", in: attributeEntries).map(\.path).isEmpty,
    "attrib: should support normal/offline and excluded temporary constants"
)

expect(
    SearchEngine.search(query: "attrib:ct", in: attributeEntries).map(\.path) == [extendedAttributeEntry.path],
    "attrib: should support temporary constants"
)

expect(
    SearchEngine.search(query: "type:image", in: categoryEntries).map(\.path) == [photo.path],
    "type:image should match image file extensions"
)

expect(
    Set(SearchEngine.search(query: "type:image;audio", in: categoryEntries).map(\.path)) ==
        Set([photo.path, audioEntry.path]),
    "type: should support semicolon OR lists"
)

expect(
    SearchEngine.search(query: "image:", in: categoryEntries).map(\.path) == [photo.path],
    "image: should match image file extensions"
)

expect(
    SearchEngine.search(query: "pics:", in: categoryEntries).map(\.path) == [photo.path],
    "pics: should alias image:"
)

expect(
    SearchEngine.search(query: "audio:", in: categoryEntries).map(\.path) == [audioEntry.path],
    "audio: should match audio file extensions"
)

expect(
    SearchEngine.search(query: "audios:", in: categoryEntries).map(\.path) == [audioEntry.path],
    "audios: should alias audio:"
)

expect(
    SearchEngine.search(query: "video:", in: categoryEntries).map(\.path) == [videoEntry.path],
    "video: should match video file extensions"
)

expect(
    SearchEngine.search(query: "document:", in: categoryEntries).map(\.path) == [document.path],
    "document: should match document file extensions"
)

expect(
    SearchEngine.search(query: "docs:", in: categoryEntries).map(\.path) == [document.path],
    "docs: should alias document:"
)

expect(
    SearchEngine.search(query: "zip:", in: categoryEntries).map(\.path) == [archiveEntry.path],
    "zip: should match compressed archive file extensions"
)

expect(
    SearchEngine.search(query: "zips:", in: categoryEntries).map(\.path) == [archiveEntry.path],
    "zips: should alias zip:"
)

expect(
    SearchEngine.search(query: "archives:", in: categoryEntries).map(\.path) == [archiveEntry.path],
    "archives: should alias zip:"
)

expect(
    SearchEngine.search(query: "type:compressed", in: categoryEntries).map(\.path) == [archiveEntry.path],
    "type:compressed should match compressed archive file extensions"
)

expect(
    Set(SearchEngine.search(query: "exe:", in: categoryEntries).map(\.path)) ==
        Set([executableScriptEntry.path, packageEntry.path]),
    "exe: should match executable scripts and app packages"
)

expect(
    Set(SearchEngine.search(query: "apps:", in: categoryEntries).map(\.path)) ==
        Set([executableScriptEntry.path, packageEntry.path]),
    "apps: should alias executable shortcuts"
)

expect(
    Set(SearchEngine.search(query: "type:executable", in: categoryEntries).map(\.path)) ==
        Set([executableScriptEntry.path, packageEntry.path]),
    "type:executable should match executable scripts and app packages"
)

expect(
    SearchEngine.search(query: "kind:folder", in: categoryEntries).map(\.path) == [folder.path],
    "kind:folder should match folders"
)

expect(
    SearchEngine.search(query: "type:package", in: categoryEntries).map(\.path) == [packageEntry.path],
    "type:package should match packages"
)

expect(
    SearchEngine.search(query: "type:link", in: categoryEntries).map(\.path) == [symlinkEntry.path],
    "type:link should match symbolic links"
)

let simpleHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch notes"))
expect(
    simpleHint.canUseDatabaseCandidates && simpleHint.terms == ["launch", "notes"],
    "simple text searches should produce SQLite candidate terms"
)

let countHint = SearchEngine.candidateHint(for: SearchRequest(query: "count:1 launch"))
expect(
    countHint.canUseDatabaseCandidates &&
        countHint.terms == ["launch"],
    "count: should not become a SQLite candidate term"
)

let extensionHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch ext:jpg"))
expect(
    extensionHint.canUseDatabaseCandidates &&
        extensionHint.terms == ["launch"] &&
        extensionHint.extensions == ["jpg"],
    "extension filters should be pushed into SQLite candidate hints"
)

let extensionListHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch ext:jpg;jpeg"))
expect(
    extensionListHint.canUseDatabaseCandidates &&
        extensionListHint.terms == ["launch"] &&
        extensionListHint.extensions == ["jpeg", "jpg"],
    "semicolon extension lists should be pushed into SQLite candidate hints"
)

let noExtensionHint = SearchEngine.candidateHint(for: SearchRequest(query: "ext:"))
expect(
    noExtensionHint.canUseDatabaseCandidates &&
        noExtensionHint.terms.isEmpty &&
        noExtensionHint.extensions == [""] &&
        noExtensionHint.kinds == [.file, .symlink, .other],
    "empty ext: should produce a structured SQLite candidate hint"
)

let categoryHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch type:document"))
expect(
    categoryHint.canUseDatabaseCandidates &&
        categoryHint.terms == ["launch"] &&
        categoryHint.kinds == [.file] &&
        categoryHint.extensions.contains("md"),
    "type filters should be pushed into SQLite candidate hints"
)

let categoryListHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch type:image;audio"))
expect(
    categoryListHint.canUseDatabaseCandidates &&
        categoryListHint.terms == ["launch"] &&
        categoryListHint.kinds == [.file] &&
        categoryListHint.extensions.contains("jpg") &&
        categoryListHint.extensions.contains("m4a"),
    "semicolon category lists should be pushed into SQLite candidate hints"
)

let compressedHint = SearchEngine.candidateHint(for: SearchRequest(query: "backup zip:"))
expect(
    compressedHint.canUseDatabaseCandidates &&
        compressedHint.terms == ["backup"] &&
        compressedHint.kinds == [.file] &&
        compressedHint.extensions.contains("zip"),
    "zip: filters should be pushed into SQLite candidate hints"
)

let compressedPluralHint = SearchEngine.candidateHint(for: SearchRequest(query: "backup zips:"))
expect(
    compressedPluralHint.canUseDatabaseCandidates &&
        compressedPluralHint.terms == ["backup"] &&
        compressedPluralHint.kinds == [.file] &&
        compressedPluralHint.extensions.contains("zip"),
    "plural compressed shortcuts should be pushed into SQLite candidate hints"
)

let executableHint = SearchEngine.candidateHint(for: SearchRequest(query: "deploy exe:"))
expect(
    executableHint.canUseDatabaseCandidates &&
        executableHint.terms == ["deploy"] &&
        executableHint.kinds == [.file, .package] &&
        executableHint.extensions.contains("command") &&
        executableHint.extensions.contains("app"),
    "exe: filters should be pushed into SQLite candidate hints"
)

let appsHint = SearchEngine.candidateHint(for: SearchRequest(query: "deploy apps:"))
expect(
    appsHint.canUseDatabaseCandidates &&
        appsHint.terms == ["deploy"] &&
        appsHint.kinds == [.file, .package] &&
        appsHint.extensions.contains("app"),
    "application shortcut aliases should be pushed into SQLite candidate hints"
)

let attributeHint = SearchEngine.candidateHint(for: SearchRequest(query: "secret hidden:"))
expect(
    attributeHint.canUseDatabaseCandidates &&
        attributeHint.terms == ["secret"] &&
        attributeHint.requiredAttributes.contains(.hidden),
    "attribute filters should be pushed into SQLite candidate hints"
)

let attributeFunctionHint = SearchEngine.candidateHint(for: SearchRequest(query: "secret attribute:h"))
expect(
    attributeFunctionHint.canUseDatabaseCandidates &&
        attributeFunctionHint.terms == ["secret"] &&
        attributeFunctionHint.requiredAttributes.contains(.hidden),
    "attribute: filters should be pushed into SQLite candidate hints"
)

let excludedAttributeHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch hidden:0"))
expect(
    excludedAttributeHint.canUseDatabaseCandidates &&
        excludedAttributeHint.terms == ["launch"] &&
        excludedAttributeHint.excludedAttributes.contains(.hidden),
    "negative attribute values should be pushed into SQLite candidate hints"
)

let sizeHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch size:>1mb"))
expect(
    sizeHint.canUseDatabaseCandidates &&
        sizeHint.terms == ["launch"] &&
        sizeHint.numericFilters.count == 1 &&
        sizeHint.numericFilters[0].field == .byteSize &&
        sizeHint.numericFilters[0].op == .greaterThan &&
        sizeHint.numericFilters[0].value == 1_024 * 1_024,
    "size filters should be pushed into SQLite candidate hints"
)

let shortSizeHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch sz:>1mb"))
expect(
    shortSizeHint.canUseDatabaseCandidates &&
        shortSizeHint.terms == ["launch"] &&
        shortSizeHint.numericFilters.count == 1 &&
        shortSizeHint.numericFilters[0].field == .byteSize &&
        shortSizeHint.numericFilters[0].op == .greaterThan &&
        shortSizeHint.numericFilters[0].value == 1_024 * 1_024,
    "sz: filters should be pushed into SQLite candidate hints"
)

let sizeRangeHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch size:1kb..3mb"))
expect(
    sizeRangeHint.canUseDatabaseCandidates &&
        sizeRangeHint.terms == ["launch"] &&
        sizeRangeHint.numericFilters.count == 2 &&
        sizeRangeHint.numericFilters[0].field == .byteSize &&
        sizeRangeHint.numericFilters[0].op == .greaterThanOrEqual &&
        sizeRangeHint.numericFilters[0].value == 1_024 &&
        sizeRangeHint.numericFilters[1].field == .byteSize &&
        sizeRangeHint.numericFilters[1].op == .lessThanOrEqual &&
        sizeRangeHint.numericFilters[1].value == 3 * 1_024 * 1_024,
    "size range filters should be pushed into SQLite candidate hints"
)

let notEqualSizeHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch size:!=1kb"))
expect(
    notEqualSizeHint.canUseDatabaseCandidates &&
        notEqualSizeHint.terms == ["launch"] &&
        notEqualSizeHint.numericFilters.count == 1 &&
        notEqualSizeHint.numericFilters[0].field == .byteSize &&
        notEqualSizeHint.numericFilters[0].op == .notEqual &&
        notEqualSizeHint.numericFilters[0].value == 1_024,
    "not-equal size filters should be pushed into SQLite candidate hints"
)

let sizeConstantHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch size:large"))
expect(
    sizeConstantHint.canUseDatabaseCandidates &&
        sizeConstantHint.terms == ["launch"] &&
        sizeConstantHint.numericFilters.count == 2 &&
        sizeConstantHint.numericFilters[0].field == .byteSize &&
        sizeConstantHint.numericFilters[0].op == .greaterThan &&
        sizeConstantHint.numericFilters[0].value == 1_024 * 1_024 &&
        sizeConstantHint.numericFilters[1].field == .byteSize &&
        sizeConstantHint.numericFilters[1].op == .lessThanOrEqual &&
        sizeConstantHint.numericFilters[1].value == 16 * 1_024 * 1_024,
    "size constants should be pushed into SQLite candidate hints"
)

let unknownSizeHint = SearchEngine.candidateHint(for: SearchRequest(query: "size:unknown"))
expect(
    unknownSizeHint.canUseDatabaseCandidates &&
        unknownSizeHint.requiresUnknownByteSize,
    "size:unknown should be pushed into SQLite null-size candidate hints"
)

let functionListHint = SearchEngine.candidateHint(for: SearchRequest(query: "stem:Launch;Notes"))
expect(
    functionListHint.canUseDatabaseCandidates == false,
    "semicolon function value lists should avoid lossy SQLite candidate prefiltering"
)

let dateHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch dm:today"))
expect(
    dateHint.canUseDatabaseCandidates &&
        dateHint.terms == ["launch"] &&
        dateHint.dateFilters.count == 2 &&
        dateHint.dateFilters.allSatisfy { $0.field == .dateModified },
    "date filters should be pushed into SQLite candidate hints"
)

let dateAliasHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch date:today"))
expect(
    dateAliasHint.canUseDatabaseCandidates &&
        dateAliasHint.terms == ["launch"] &&
        dateAliasHint.dateFilters.count == 2 &&
        dateAliasHint.dateFilters.allSatisfy { $0.field == .dateModified },
    "date: should alias date-modified: in SQLite candidate hints"
)

let dashedDateHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch date-modified:today"))
expect(
    dashedDateHint.canUseDatabaseCandidates &&
        dashedDateHint.terms == ["launch"] &&
        dashedDateHint.dateFilters.count == 2 &&
        dashedDateHint.dateFilters.allSatisfy { $0.field == .dateModified },
    "dashed date filters should be pushed into SQLite candidate hints"
)

let modifiedDateOnlyHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch date-modified-date:today"))
expect(
    modifiedDateOnlyHint.canUseDatabaseCandidates &&
        modifiedDateOnlyHint.terms == ["launch"] &&
        modifiedDateOnlyHint.dateFilters.count == 2 &&
        modifiedDateOnlyHint.dateFilters.allSatisfy { $0.field == .dateModified },
    "date-modified-date: should alias date-modified: in SQLite candidate hints"
)

let createdDateOnlyHint = SearchEngine.candidateHint(for: SearchRequest(query: "budget date-created-date:1970-01-01"))
expect(
    createdDateOnlyHint.canUseDatabaseCandidates &&
        createdDateOnlyHint.terms == ["budget"] &&
        createdDateOnlyHint.dateFilters.count == 2 &&
        createdDateOnlyHint.dateFilters.allSatisfy { $0.field == .dateCreated },
    "date-created-date: should alias date-created: in SQLite candidate hints"
)

let accessedDateOnlyHint = SearchEngine.candidateHint(for: SearchRequest(query: "budget date-accessed-date:1970-01-01"))
expect(
    accessedDateOnlyHint.canUseDatabaseCandidates &&
        accessedDateOnlyHint.terms == ["budget"] &&
        accessedDateOnlyHint.dateFilters.count == 2 &&
        accessedDateOnlyHint.dateFilters.allSatisfy { $0.field == .dateAccessed },
    "date-accessed-date: should alias date-accessed: in SQLite candidate hints"
)

let dateRunHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch dr:1970-01-01"))
expect(
    dateRunHint.canUseDatabaseCandidates &&
        dateRunHint.terms == ["launch"] &&
        dateRunHint.dateFilters.count == 2 &&
        dateRunHint.dateFilters.allSatisfy { $0.field == .dateRun },
    "date-run filters should be pushed into SQLite candidate hints"
)

let unknownDateHint = SearchEngine.candidateHint(for: SearchRequest(query: "dm:unknown"))
expect(
    unknownDateHint.canUseDatabaseCandidates &&
        unknownDateHint.unknownDateFields == [.dateModified],
    "dm:unknown should be pushed into SQLite null-date candidate hints"
)

let unknownDateAliasHint = SearchEngine.candidateHint(for: SearchRequest(query: "date-created:unknown"))
expect(
    unknownDateAliasHint.canUseDatabaseCandidates &&
        unknownDateAliasHint.unknownDateFields == [.dateCreated],
    "date-created:unknown should be pushed into SQLite null-date candidate hints"
)

let runCountHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch runcount:>1"))
expect(
    runCountHint.canUseDatabaseCandidates &&
        runCountHint.terms == ["launch"] &&
        runCountHint.numericFilters.count == 1 &&
        runCountHint.numericFilters[0].field == .runCount &&
        runCountHint.numericFilters[0].op == .greaterThan &&
        runCountHint.numericFilters[0].value == 1,
    "run-count filters should be pushed into SQLite candidate hints"
)

let dashedRunCountHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch run-count:>1"))
expect(
    dashedRunCountHint.canUseDatabaseCandidates &&
        dashedRunCountHint.terms == ["launch"] &&
        dashedRunCountHint.numericFilters.count == 1 &&
        dashedRunCountHint.numericFilters[0].field == .runCount &&
        dashedRunCountHint.numericFilters[0].op == .greaterThan &&
        dashedRunCountHint.numericFilters[0].value == 1,
    "dashed run-count filters should be pushed into SQLite candidate hints"
)

let startWithHint = SearchEngine.candidateHint(for: SearchRequest(query: "startwith:Launch"))
expect(
    startWithHint.canUseDatabaseCandidates &&
        startWithHint.terms == ["Launch"],
    "startwith: should produce a SQLite candidate term"
)

let stemHint = SearchEngine.candidateHint(for: SearchRequest(query: "stem:Notes"))
expect(
    stemHint.canUseDatabaseCandidates &&
        stemHint.terms == ["Notes"],
    "stem: should produce a SQLite candidate term"
)

let basenameHint = SearchEngine.candidateHint(for: SearchRequest(query: "basename:Notes"))
expect(
    basenameHint.canUseDatabaseCandidates &&
        basenameHint.terms == ["Notes"],
    "basename: should produce a SQLite candidate term"
)

let stemLengthHint = SearchEngine.candidateHint(for: SearchRequest(query: "stem-len:>5"))
expect(
    stemLengthHint.canUseDatabaseCandidates &&
        stemLengthHint.numericFilters.count == 1 &&
        stemLengthHint.numericFilters[0].field == .namePartLength &&
        stemLengthHint.numericFilters[0].op == .greaterThan &&
        stemLengthHint.numericFilters[0].value == 5,
    "stem-len: searches should be pushed into SQLite length candidate hints"
)

let charsHint = SearchEngine.candidateHint(for: SearchRequest(query: "chars:>5"))
expect(
    charsHint.canUseDatabaseCandidates &&
        charsHint.numericFilters.count == 1 &&
        charsHint.numericFilters[0].field == .characterCount &&
        charsHint.numericFilters[0].op == .greaterThan &&
        charsHint.numericFilters[0].value == 5,
    "chars: searches should be pushed into SQLite character-count candidate hints"
)

let filenameLengthHint = SearchEngine.candidateHint(for: SearchRequest(query: "filename-len:>5"))
expect(
    filenameLengthHint.canUseDatabaseCandidates &&
        filenameLengthHint.numericFilters.count == 1 &&
        filenameLengthHint.numericFilters[0].field == .pathLength &&
        filenameLengthHint.numericFilters[0].op == .greaterThan &&
        filenameLengthHint.numericFilters[0].value == 5,
    "filename-len: searches should be pushed into SQLite path-length candidate hints"
)

let utf8LengthHint = SearchEngine.candidateHint(for: SearchRequest(query: "utf8-len:>8"))
expect(
    utf8LengthHint.canUseDatabaseCandidates &&
        utf8LengthHint.numericFilters.count == 1 &&
        utf8LengthHint.numericFilters[0].field == .nameUTF8Length &&
        utf8LengthHint.numericFilters[0].op == .greaterThan &&
        utf8LengthHint.numericFilters[0].value == 8,
    "utf8-len: searches should be pushed into SQLite UTF-8 length candidate hints"
)

let pathPartHint = SearchEngine.candidateHint(for: SearchRequest(query: "path-part:Documents"))
expect(
    pathPartHint.canUseDatabaseCandidates &&
        pathPartHint.terms == ["Documents"],
    "path-part: should produce a SQLite candidate term"
)

let fullPathHint = SearchEngine.candidateHint(for: SearchRequest(query: "full-path:/Users/me/project/archive"))
expect(
    fullPathHint.canUseDatabaseCandidates &&
        fullPathHint.terms == ["/Users/me/project/archive"],
    "full-path: should produce a SQLite candidate term"
)

let wildcardFullPathHint = SearchEngine.candidateHint(for: SearchRequest(query: "full-path:/Users/me/project/*/readme.txt"))
expect(
    wildcardFullPathHint.canUseDatabaseCandidates == false,
    "wildcard full-path: searches should avoid lossy SQLite candidate prefiltering"
)

let locationHint = SearchEngine.candidateHint(for: SearchRequest(query: "location:Pictures"))
expect(
    locationHint.canUseDatabaseCandidates &&
        locationHint.terms == ["Pictures"],
    "location: should produce a SQLite candidate term"
)

let pathLengthHint = SearchEngine.candidateHint(for: SearchRequest(query: "path-len:>20"))
expect(
    pathLengthHint.canUseDatabaseCandidates &&
        pathLengthHint.numericFilters.count == 1 &&
        pathLengthHint.numericFilters[0].field == .pathLength &&
        pathLengthHint.numericFilters[0].op == .greaterThan &&
        pathLengthHint.numericFilters[0].value == 20,
    "path-len: searches should be pushed into SQLite path-length candidate hints"
)

let pathPartLengthHint = SearchEngine.candidateHint(for: SearchRequest(query: "path-part-len:>20"))
expect(
    pathPartLengthHint.canUseDatabaseCandidates &&
        pathPartLengthHint.numericFilters.count == 1 &&
        pathPartLengthHint.numericFilters[0].field == .pathPartLength &&
        pathPartLengthHint.numericFilters[0].op == .greaterThan &&
        pathPartLengthHint.numericFilters[0].value == 20,
    "path-part-len: searches should be pushed into SQLite parent-length candidate hints"
)

let extensionLengthHint = SearchEngine.candidateHint(for: SearchRequest(query: "ext-len:3"))
expect(
    extensionLengthHint.canUseDatabaseCandidates &&
        extensionLengthHint.numericFilters.count == 1 &&
        extensionLengthHint.numericFilters[0].field == .extensionLength &&
        extensionLengthHint.numericFilters[0].op == .equal &&
        extensionLengthHint.numericFilters[0].value == 3,
    "ext-len: searches should be pushed into SQLite extension-length candidate hints"
)

let parentCountHint = SearchEngine.candidateHint(for: SearchRequest(query: "parent-count:>3"))
expect(
    parentCountHint.canUseDatabaseCandidates &&
        parentCountHint.numericFilters.count == 1 &&
        parentCountHint.numericFilters[0].field == .depth &&
        parentCountHint.numericFilters[0].op == .greaterThan &&
        parentCountHint.numericFilters[0].value == 3,
    "parent-count filters should be pushed into SQLite depth candidate hints"
)

let dashedStartWithHint = SearchEngine.candidateHint(for: SearchRequest(query: "start-with:Launch"))
expect(
    dashedStartWithHint.canUseDatabaseCandidates &&
        dashedStartWithHint.terms == ["Launch"],
    "dashed start-with filters should produce a SQLite candidate term"
)

let parentHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch parent:/Users/me/Documents"))
expect(
    parentHint.canUseDatabaseCandidates &&
        parentHint.terms == ["launch"] &&
        parentHint.parentPaths == ["/Users/me/Documents"],
    "absolute parent filters should be pushed into SQLite candidate hints"
)

let parentPathHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch parent-path:/Users/me/Documents"))
expect(
    parentPathHint.canUseDatabaseCandidates &&
        parentPathHint.terms == ["launch", "/Users/me/Documents"] &&
        parentPathHint.parentPaths.isEmpty,
    "parent-path filters should use text candidate terms instead of exact parent filters"
)

let partialParentPathHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch parent-path:/Users/me/Doc"))
expect(
    partialParentPathHint.canUseDatabaseCandidates &&
        partialParentPathHint.terms == ["launch", "/Users/me/Doc"] &&
        partialParentPathHint.parentPaths.isEmpty,
    "partial parent-path filters should remain safe text candidate terms"
)

let relativeParentHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch parent:Documents"))
expect(
    relativeParentHint.canUseDatabaseCandidates == false,
    "relative parent filters should avoid lossy SQLite candidate prefiltering"
)

let relativeParentPathHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch parent-path:Documents"))
expect(
    relativeParentPathHint.canUseDatabaseCandidates &&
        relativeParentPathHint.terms == ["launch", "Documents"],
    "relative parent-path filters should use SQLite candidate terms"
)

let parentPlusHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch parent+1:/Users/me/Documents"))
expect(
    parentPlusHint.canUseDatabaseCandidates == false,
    "parent+N: searches should avoid lossy SQLite candidate prefiltering"
)

let parentDepthHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch parent-depth1:/Users/me/Documents"))
expect(
    parentDepthHint.canUseDatabaseCandidates == false,
    "parent-depthN: searches should avoid lossy SQLite candidate prefiltering"
)

let parentDateHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch parent-dm:>2024-01-01"))
expect(
    parentDateHint.canUseDatabaseCandidates &&
        parentDateHint.terms == ["launch"] &&
        parentDateHint.parentDateFilters.count == 1,
    "parent-dm: searches should be pushed into SQLite candidate hints"
)

let unknownParentDateHint = SearchEngine.candidateHint(for: SearchRequest(query: "parent-dm:unknown"))
expect(
    unknownParentDateHint.canUseDatabaseCandidates == false,
    "parent unknown-date searches should avoid lossy SQLite candidate prefiltering"
)

let parentSizeHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch parent-size:>1kb"))
expect(
    parentSizeHint.canUseDatabaseCandidates &&
        parentSizeHint.terms == ["launch"] &&
        parentSizeHint.parentSizeFilters.count == 1,
    "parent-size: searches should be pushed into SQLite candidate hints"
)

let ancestorHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch ancestor:/Users/me/Documents"))
expect(
    ancestorHint.canUseDatabaseCandidates &&
        ancestorHint.terms == ["launch", "/Users/me/Documents"],
    "absolute ancestor: searches should use path text candidate terms"
)

let parentNameHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch parent-name:Documents"))
expect(
    parentNameHint.canUseDatabaseCandidates &&
        parentNameHint.terms == ["launch", "Documents"],
    "parent-name: searches should use parent text candidate terms"
)

let ancestorNameHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch ancestor-name:Documents"))
expect(
    ancestorNameHint.canUseDatabaseCandidates &&
        ancestorNameHint.terms == ["launch", "Documents"],
    "ancestor-name: searches should use ancestor text candidate terms"
)

let parentChildHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch parent-child:Empty"))
expect(
    parentChildHint.canUseDatabaseCandidates == false,
    "parent-child: searches should avoid lossy SQLite candidate prefiltering"
)

let parentChildPresenceHint = SearchEngine.candidateHint(for: SearchRequest(query: "parent-child:"))
expect(
    parentChildPresenceHint.canUseDatabaseCandidates &&
        parentChildPresenceHint.parentChildFilters.first?.value == nil,
    "parent-child: presence searches should be pushed into SQLite candidate hints"
)

let exactParentChildOptions = SearchOptions(caseSensitive: true, diacriticSensitive: true)

let exactNameContainsHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "name:NeedlePrefix", options: exactParentChildOptions)
)
expect(
    exactNameContainsHint.canUseDatabaseCandidates &&
        exactNameContainsHint.terms.isEmpty &&
        exactNameContainsHint.nameFilters.first?.field == .name &&
        exactNameContainsHint.nameFilters.first?.mode == .contains &&
        exactNameContainsHint.nameFilters.first?.values == Set(["NeedlePrefix"]),
    "exact name: filters should be pushed into SQLite name-contains candidate hints"
)

let exactStemContainsHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "stem:NeedlePrefix", options: exactParentChildOptions)
)
expect(
    exactStemContainsHint.canUseDatabaseCandidates &&
        exactStemContainsHint.terms.isEmpty &&
        exactStemContainsHint.nameFilters.first?.field == .namePart &&
        exactStemContainsHint.nameFilters.first?.mode == .contains &&
        exactStemContainsHint.nameFilters.first?.values == Set(["NeedlePrefix"]),
    "exact stem: filters should be pushed into SQLite name-part candidate hints"
)

let exactPathPartContainsHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "path-part:/Users/me/PathNeedle", options: exactParentChildOptions)
)
expect(
    exactPathPartContainsHint.canUseDatabaseCandidates &&
        exactPathPartContainsHint.terms.isEmpty &&
        exactPathPartContainsHint.nameFilters.first?.field == .pathPart &&
        exactPathPartContainsHint.nameFilters.first?.mode == .contains &&
        exactPathPartContainsHint.nameFilters.first?.values == Set(["/Users/me/PathNeedle"]),
    "exact path-part: filters should be pushed into SQLite path-part candidate hints"
)

let exactStartWithHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "start-with:Launch", options: exactParentChildOptions)
)
expect(
    exactStartWithHint.canUseDatabaseCandidates &&
        exactStartWithHint.terms.isEmpty &&
        exactStartWithHint.nameFilters.first?.mode == .prefix &&
        exactStartWithHint.nameFilters.first?.values == Set(["Launch"]),
    "exact start-with filters should be pushed into SQLite name-prefix candidate hints"
)

let exactEndWithHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "end-with:.md", options: exactParentChildOptions)
)
expect(
    exactEndWithHint.canUseDatabaseCandidates &&
        exactEndWithHint.terms.isEmpty &&
        exactEndWithHint.nameFilters.first?.mode == .suffix &&
        exactEndWithHint.nameFilters.first?.values == Set([".md"]),
    "exact end-with filters should be pushed into SQLite name-suffix candidate hints"
)

let exactWholeFilenameHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "exact:Launch.md", options: exactParentChildOptions)
)
expect(
    exactWholeFilenameHint.canUseDatabaseCandidates &&
        exactWholeFilenameHint.terms.isEmpty &&
        exactWholeFilenameHint.nameFilters.first?.mode == .equal &&
        exactWholeFilenameHint.nameFilters.first?.values == Set(["Launch.md"]),
    "exact whole-filename filters should be pushed into SQLite name-equality candidate hints"
)

let exactParentChildHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "parent-child:Empty", options: exactParentChildOptions)
)
expect(
    exactParentChildHint.canUseDatabaseCandidates &&
        exactParentChildHint.parentChildFilters.first?.value == "Empty",
    "exact parent-child: searches should be pushed into SQLite candidate hints"
)

let exactParentChildFolderHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "parent-child-folder:Launch", options: exactParentChildOptions)
)
expect(
    exactParentChildFolderHint.canUseDatabaseCandidates &&
        exactParentChildFolderHint.parentChildFilters.first?.allowedKinds == Set<FileKind>([.folder, .package]),
    "exact parent-child-folder: searches should preserve kind filters in SQLite candidate hints"
)

let parentSiblingHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch parent-sibling:Empty"))
expect(
    parentSiblingHint.canUseDatabaseCandidates == false,
    "parent-sibling: searches should avoid lossy SQLite candidate prefiltering"
)

let parentSiblingPresenceHint = SearchEngine.candidateHint(for: SearchRequest(query: "parent-sibling:"))
expect(
    parentSiblingPresenceHint.canUseDatabaseCandidates &&
        parentSiblingPresenceHint.parentSiblingFilters.first?.value == nil,
    "parent-sibling: presence searches should be pushed into SQLite candidate hints"
)

let exactParentSiblingHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "parent-sibling:Empty", options: exactParentChildOptions)
)
expect(
    exactParentSiblingHint.canUseDatabaseCandidates &&
        exactParentSiblingHint.parentSiblingFilters.first?.value == "Empty",
    "exact parent-sibling: searches should be pushed into SQLite candidate hints"
)

let exactParentSiblingFolderHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "parent-sibling-folder:Archive", options: exactParentChildOptions)
)
expect(
    exactParentSiblingFolderHint.canUseDatabaseCandidates &&
        exactParentSiblingFolderHint.parentSiblingFilters.first?.allowedKinds == Set<FileKind>([.folder, .package]),
    "exact parent-sibling-folder: searches should preserve kind filters in SQLite candidate hints"
)

let ancestorSiblingHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch ancestor-sibling:Empty"))
expect(
    ancestorSiblingHint.canUseDatabaseCandidates == false,
    "ancestor-sibling: searches should avoid lossy SQLite candidate prefiltering"
)

let ancestorSiblingPresenceHint = SearchEngine.candidateHint(for: SearchRequest(query: "ancestor-sibling:"))
expect(
    ancestorSiblingPresenceHint.canUseDatabaseCandidates &&
        ancestorSiblingPresenceHint.ancestorSiblingFilters.first?.value == nil,
    "ancestor-sibling: presence searches should be pushed into SQLite candidate hints"
)

let exactAncestorSiblingHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "ancestor-sibling:Empty", options: exactParentChildOptions)
)
expect(
    exactAncestorSiblingHint.canUseDatabaseCandidates &&
        exactAncestorSiblingHint.ancestorSiblingFilters.first?.value == "Empty",
    "exact ancestor-sibling: searches should be pushed into SQLite candidate hints"
)

let exactAncestorSiblingFolderHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "ancestor-sibling-folder:Archive", options: exactParentChildOptions)
)
expect(
    exactAncestorSiblingFolderHint.canUseDatabaseCandidates &&
        exactAncestorSiblingFolderHint.ancestorSiblingFilters.first?.allowedKinds == Set<FileKind>([.folder, .package]),
    "exact ancestor-sibling-folder: searches should preserve kind filters in SQLite candidate hints"
)

let complexHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch | notes"))
expect(
    complexHint.canUseDatabaseCandidates == false,
    "OR searches should avoid lossy SQLite candidate prefiltering"
)

let groupedHint = SearchEngine.candidateHint(for: SearchRequest(query: "(launch | notes) file:"))
expect(
    groupedHint.canUseDatabaseCandidates == false,
    "parenthesized searches should avoid lossy SQLite candidate prefiltering"
)

let angleGroupedHint = SearchEngine.candidateHint(for: SearchRequest(query: "<launch | notes> file:"))
expect(
    angleGroupedHint.canUseDatabaseCandidates == false,
    "angle-bracket searches should avoid lossy SQLite candidate prefiltering"
)

let substitutionHint = SearchEngine.candidateHint(for: SearchRequest(query: "stem:.$extension:"))
expect(
    substitutionHint.canUseDatabaseCandidates == false,
    "property substitution searches should avoid lossy SQLite candidate prefiltering"
)

let childHint = SearchEngine.candidateHint(for: SearchRequest(query: "child:Child"))
expect(
    childHint.canUseDatabaseCandidates == false,
    "child: searches should avoid lossy SQLite candidate prefiltering"
)

let childPresenceHint = SearchEngine.candidateHint(for: SearchRequest(query: "child:"))
expect(
    childPresenceHint.canUseDatabaseCandidates &&
        childPresenceHint.childTextFilters.first?.value == nil,
    "child: presence searches should be pushed into SQLite candidate hints"
)

let exactChildHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "child:Child", options: exactParentChildOptions)
)
expect(
    exactChildHint.canUseDatabaseCandidates &&
        exactChildHint.childTextFilters.first?.value == "Child",
    "exact child: searches should be pushed into SQLite candidate hints"
)

let childFileHint = SearchEngine.candidateHint(for: SearchRequest(query: "child-file:Child"))
expect(
    childFileHint.canUseDatabaseCandidates == false,
    "child-file: searches should avoid lossy SQLite candidate prefiltering"
)

let exactChildFolderHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "child-folder:Nested", options: exactParentChildOptions)
)
expect(
    exactChildFolderHint.canUseDatabaseCandidates &&
        exactChildFolderHint.childTextFilters.first?.allowedKinds == Set<FileKind>([.folder, .package]),
    "exact child-folder: searches should preserve kind filters in SQLite candidate hints"
)

let childCountHint = SearchEngine.candidateHint(for: SearchRequest(query: "childcount:>0"))
expect(
    childCountHint.canUseDatabaseCandidates &&
        childCountHint.numericFilters.first?.field == .childCount,
    "childcount: searches should be pushed into SQLite candidate hints"
)

let childFileCountHint = SearchEngine.candidateHint(for: SearchRequest(query: "childfilecount:>0"))
expect(
    childFileCountHint.canUseDatabaseCandidates &&
        childFileCountHint.numericFilters.first?.field == .childFileCount,
    "childfilecount: searches should be pushed into SQLite candidate hints"
)

let dashedChildFileCountHint = SearchEngine.candidateHint(for: SearchRequest(query: "child-file-count:>0"))
expect(
    dashedChildFileCountHint.canUseDatabaseCandidates &&
        dashedChildFileCountHint.numericFilters.first?.field == .childFileCount,
    "dashed child-file-count: searches should be pushed into SQLite candidate hints"
)

let childFolderCountHint = SearchEngine.candidateHint(for: SearchRequest(query: "childfoldercount:>0"))
expect(
    childFolderCountHint.canUseDatabaseCandidates &&
        childFolderCountHint.numericFilters.first?.field == .childFolderCount,
    "childfoldercount: searches should be pushed into SQLite candidate hints"
)

let totalChildSizeHint = SearchEngine.candidateHint(for: SearchRequest(query: "total-child-size:>1kb"))
expect(
    totalChildSizeHint.canUseDatabaseCandidates &&
        totalChildSizeHint.numericFilters.first?.field == .totalChildSize,
    "total-child-size: searches should be pushed into SQLite candidate hints"
)

let descendantHint = SearchEngine.candidateHint(for: SearchRequest(query: "descendant:Grandchild"))
expect(
    descendantHint.canUseDatabaseCandidates == false,
    "descendant: searches should avoid lossy SQLite candidate prefiltering"
)

let descendantPresenceHint = SearchEngine.candidateHint(for: SearchRequest(query: "descendant:"))
expect(
    descendantPresenceHint.canUseDatabaseCandidates &&
        descendantPresenceHint.descendantTextFilters.first?.value == nil,
    "descendant: presence searches should be pushed into SQLite candidate hints"
)

let exactDescendantHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "descendant:Grandchild", options: exactParentChildOptions)
)
expect(
    exactDescendantHint.canUseDatabaseCandidates &&
        exactDescendantHint.descendantTextFilters.first?.value == "Grandchild",
    "exact descendant: searches should be pushed into SQLite candidate hints"
)

let exactDescendantFolderHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "descendant-folder:Nested", options: exactParentChildOptions)
)
expect(
    exactDescendantFolderHint.canUseDatabaseCandidates &&
        exactDescendantFolderHint.descendantTextFilters.first?.allowedKinds == Set<FileKind>([.folder, .package]),
    "exact descendant-folder: searches should preserve kind filters in SQLite candidate hints"
)

let descendantCountHint = SearchEngine.candidateHint(for: SearchRequest(query: "descendant-count:>0"))
expect(
    descendantCountHint.canUseDatabaseCandidates &&
        descendantCountHint.numericFilters.first?.field == .descendantCount,
    "descendant-count: searches should be pushed into SQLite candidate hints"
)

let descendantFileCountHint = SearchEngine.candidateHint(for: SearchRequest(query: "descendant-file-count:>0"))
expect(
    descendantFileCountHint.canUseDatabaseCandidates &&
        descendantFileCountHint.numericFilters.first?.field == .descendantFileCount,
    "descendant-file-count: searches should be pushed into SQLite candidate hints"
)

let descendantFolderCountHint = SearchEngine.candidateHint(for: SearchRequest(query: "descendant-folder-count:>0"))
expect(
    descendantFolderCountHint.canUseDatabaseCandidates &&
        descendantFolderCountHint.numericFilters.first?.field == .descendantFolderCount,
    "descendant-folder-count: searches should be pushed into SQLite candidate hints"
)

let ancestorAttributeHint = SearchEngine.candidateHint(for: SearchRequest(query: "ancestor-attr:h"))
expect(
    ancestorAttributeHint.canUseDatabaseCandidates &&
        ancestorAttributeHint.ancestorAttributeFilters.first?.requiredAttributes == .hidden,
    "ancestor-attr: searches should be pushed into SQLite candidate hints"
)

let excludedAncestorAttributeHint = SearchEngine.candidateHint(for: SearchRequest(query: "ancestor-attr:!h"))
expect(
    excludedAncestorAttributeHint.canUseDatabaseCandidates &&
        excludedAncestorAttributeHint.ancestorAttributeFilters.first?.excludedAttributes == .hidden,
    "negative ancestor-attr: searches should be pushed into SQLite candidate hints"
)

let ancestorChildHint = SearchEngine.candidateHint(for: SearchRequest(query: "ancestor-child-file:Child"))
expect(
    ancestorChildHint.canUseDatabaseCandidates == false,
    "ancestor-child-file: searches should avoid lossy SQLite candidate prefiltering"
)

let ancestorChildPresenceHint = SearchEngine.candidateHint(for: SearchRequest(query: "ancestor-child:"))
expect(
    ancestorChildPresenceHint.canUseDatabaseCandidates &&
        ancestorChildPresenceHint.ancestorChildFilters.first?.value == nil,
    "ancestor-child: presence searches should be pushed into SQLite candidate hints"
)

let exactAncestorChildHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "ancestor-child:Child", options: exactParentChildOptions)
)
expect(
    exactAncestorChildHint.canUseDatabaseCandidates &&
        exactAncestorChildHint.ancestorChildFilters.first?.value == "Child",
    "exact ancestor-child: searches should be pushed into SQLite candidate hints"
)

let exactAncestorChildFolderHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "ancestor-child-folder:Nested", options: exactParentChildOptions)
)
expect(
    exactAncestorChildFolderHint.canUseDatabaseCandidates &&
        exactAncestorChildFolderHint.ancestorChildFilters.first?.allowedKinds == Set<FileKind>([.folder, .package]),
    "exact ancestor-child-folder: searches should preserve kind filters in SQLite candidate hints"
)

let childAttributeHint = SearchEngine.candidateHint(for: SearchRequest(query: "child-file-attr:h"))
expect(
    childAttributeHint.canUseDatabaseCandidates &&
        childAttributeHint.childAttributeFilters.contains {
            $0.allowedKinds == Set<FileKind>([.file, .symlink, .other]) &&
                $0.requiredAttributes.contains(.hidden)
        },
    "child-file-attr: searches should be pushed into SQLite candidate hints"
)

let childExcludedAttributeHint = SearchEngine.candidateHint(for: SearchRequest(query: "child-file-attr:!h"))
expect(
    childExcludedAttributeHint.canUseDatabaseCandidates &&
        childExcludedAttributeHint.childAttributeFilters.contains {
            $0.allowedKinds == Set<FileKind>([.file, .symlink, .other]) &&
                $0.excludedAttributes.contains(.hidden)
        },
    "negative child-file-attr: searches should be pushed into SQLite candidate hints"
)

let childFolderAttributeHint = SearchEngine.candidateHint(for: SearchRequest(query: "child-folder-attr:d"))
expect(
    childFolderAttributeHint.canUseDatabaseCandidates &&
        childFolderAttributeHint.childAttributeFilters.contains {
            $0.allowedKinds == Set<FileKind>([.folder, .package]) &&
                $0.requiredAttributes.contains(.directory)
        },
    "child-folder-attr: searches should be pushed into SQLite candidate hints"
)

let childDateHint = SearchEngine.candidateHint(for: SearchRequest(query: "child-dm:>2024-01-01"))
expect(
    childDateHint.canUseDatabaseCandidates &&
        childDateHint.childDateFilters.count == 1,
    "child-dm: searches should be pushed into SQLite candidate hints"
)

let childFileDateHint = SearchEngine.candidateHint(for: SearchRequest(query: "child-file-date-accessed:2024-05-03"))
expect(
    childFileDateHint.canUseDatabaseCandidates &&
        childFileDateHint.childDateFilters.contains {
            $0.allowedKinds == Set<FileKind>([.file, .symlink, .other])
        },
    "child-file date searches should be pushed into SQLite candidate hints"
)

let unknownChildDateHint = SearchEngine.candidateHint(for: SearchRequest(query: "child-dm:unknown"))
expect(
    unknownChildDateHint.canUseDatabaseCandidates == false,
    "child unknown-date searches should avoid lossy SQLite candidate prefiltering"
)

let childRunCountHint = SearchEngine.candidateHint(for: SearchRequest(query: "child-run-count:>0"))
expect(
    childRunCountHint.canUseDatabaseCandidates &&
        childRunCountHint.childRunCountFilters.count == 1,
    "child-run-count: searches should be pushed into SQLite candidate hints"
)

let childFileRunCountHint = SearchEngine.candidateHint(for: SearchRequest(query: "child-file-run-count:>0"))
expect(
    childFileRunCountHint.canUseDatabaseCandidates &&
        childFileRunCountHint.childRunCountFilters.contains {
            $0.allowedKinds == Set<FileKind>([.file, .symlink, .other])
        },
    "child-file-run-count: searches should be pushed into SQLite candidate hints"
)

let childFolderRunCountHint = SearchEngine.candidateHint(for: SearchRequest(query: "child-folder-run-count:>0"))
expect(
    childFolderRunCountHint.canUseDatabaseCandidates &&
        childFolderRunCountHint.childRunCountFilters.contains {
            $0.allowedKinds == Set<FileKind>([.folder, .package])
        },
    "child-folder-run-count: searches should be pushed into SQLite candidate hints"
)

let childSizeHint = SearchEngine.candidateHint(for: SearchRequest(query: "child-size:>1kb"))
expect(
    childSizeHint.canUseDatabaseCandidates &&
        childSizeHint.childSizeFilters.count == 1,
    "child-size: searches should be pushed into SQLite candidate hints"
)

let childFileSizeHint = SearchEngine.candidateHint(for: SearchRequest(query: "child-file-size:>1kb"))
expect(
    childFileSizeHint.canUseDatabaseCandidates &&
        childFileSizeHint.childSizeFilters.contains {
            $0.allowedKinds == Set<FileKind>([.file, .symlink, .other])
        },
    "child-file-size: searches should be pushed into SQLite candidate hints"
)

let childFolderSizeHint = SearchEngine.candidateHint(for: SearchRequest(query: "child-folder-size:>1kb"))
expect(
    childFolderSizeHint.canUseDatabaseCandidates &&
        childFolderSizeHint.childSizeFilters.contains {
            $0.allowedKinds == Set<FileKind>([.folder, .package])
        },
    "child-folder-size: searches should be pushed into SQLite candidate hints"
)

let childFileListHint = SearchEngine.candidateHint(for: SearchRequest(query: "child-file-list:Metadata.bin"))
expect(
    childFileListHint.canUseDatabaseCandidates == false,
    "default child-file-list: searches should avoid lossy SQLite candidate prefiltering"
)

let exactChildFileListOptions = SearchOptions(caseSensitive: true, diacriticSensitive: true)
let exactChildFileListHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "child-file-list:Metadata.bin", options: exactChildFileListOptions)
)
expect(
    exactChildFileListHint.canUseDatabaseCandidates &&
        exactChildFileListHint.childFileListFilters.first?.nameValues == Set(["Metadata.bin"]),
    "exact child-file-list: searches should be pushed into SQLite candidate hints"
)

let exactChildFileListPathHint = SearchEngine.candidateHint(
    for: SearchRequest(
        query: "child-file-list:/Users/me/Documents/Launch/MetadataFolder",
        options: exactChildFileListOptions
    )
)
expect(
    exactChildFileListPathHint.canUseDatabaseCandidates &&
        exactChildFileListPathHint.childFileListFilters.first?.pathValues == Set([
            "/Users/me/Documents/Launch/MetadataFolder"
        ]),
    "exact child-file-list: path values should be normalized for SQLite candidate hints"
)

let siblingHint = SearchEngine.candidateHint(for: SearchRequest(query: "sibling:Launch"))
expect(
    siblingHint.canUseDatabaseCandidates == false,
    "sibling: searches should avoid lossy SQLite candidate prefiltering"
)

let siblingPresenceHint = SearchEngine.candidateHint(for: SearchRequest(query: "sibling:"))
expect(
    siblingPresenceHint.canUseDatabaseCandidates &&
        siblingPresenceHint.siblingFilters.first?.value == nil,
    "sibling: presence searches should be pushed into SQLite candidate hints"
)

let exactSiblingHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "sibling:Empty", options: exactParentChildOptions)
)
expect(
    exactSiblingHint.canUseDatabaseCandidates &&
        exactSiblingHint.siblingFilters.first?.value == "Empty",
    "exact sibling: searches should be pushed into SQLite candidate hints"
)

let exactSiblingFolderHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "sibling-folder:Launch", options: exactParentChildOptions)
)
expect(
    exactSiblingFolderHint.canUseDatabaseCandidates &&
        exactSiblingFolderHint.siblingFilters.first?.allowedKinds == Set<FileKind>([.folder, .package]),
    "exact sibling-folder: searches should preserve kind filters in SQLite candidate hints"
)

let siblingCountHint = SearchEngine.candidateHint(for: SearchRequest(query: "sibling-count:>0"))
expect(
    siblingCountHint.canUseDatabaseCandidates &&
        siblingCountHint.numericFilters.first?.field == .siblingCount,
    "sibling-count: searches should be pushed into SQLite candidate hints"
)

let siblingFileCountHint = SearchEngine.candidateHint(for: SearchRequest(query: "sibling-file-count:>0"))
expect(
    siblingFileCountHint.canUseDatabaseCandidates &&
        siblingFileCountHint.numericFilters.first?.field == .siblingFileCount,
    "sibling-file-count: searches should be pushed into SQLite candidate hints"
)

let siblingFolderCountHint = SearchEngine.candidateHint(for: SearchRequest(query: "sibling-folder-count:>0"))
expect(
    siblingFolderCountHint.canUseDatabaseCandidates &&
        siblingFolderCountHint.numericFilters.first?.field == .siblingFolderCount,
    "sibling-folder-count: searches should be pushed into SQLite candidate hints"
)

let sizeDupeHint = SearchEngine.candidateHint(for: SearchRequest(query: "sizedupe:"))
expect(
    sizeDupeHint.canUseDatabaseCandidates &&
        sizeDupeHint.numericFilters.first?.field == .byteSizeFrequency,
    "size duplicate searches should be pushed into SQLite candidate hints"
)

let uniqueSizeHint = SearchEngine.candidateHint(for: SearchRequest(query: "sizedupe:0"))
expect(
    uniqueSizeHint.canUseDatabaseCandidates &&
        uniqueSizeHint.numericFilters.first?.field == .byteSizeFrequency &&
        uniqueSizeHint.numericFilters.first?.op == .lessThanOrEqual,
    "unique size searches should be pushed into SQLite candidate hints"
)

let modifiedDupeHint = SearchEngine.candidateHint(for: SearchRequest(query: "dmdupe:"))
expect(
    modifiedDupeHint.canUseDatabaseCandidates &&
        modifiedDupeHint.numericFilters.first?.field == .modifiedDateFrequency,
    "modified-date duplicate searches should be pushed into SQLite candidate hints"
)

let attributeDupeHint = SearchEngine.candidateHint(for: SearchRequest(query: "attribdupe:"))
expect(
    attributeDupeHint.canUseDatabaseCandidates &&
        attributeDupeHint.numericFilters.first?.field == .attributeFrequency,
    "attribute duplicate searches should be pushed into SQLite candidate hints"
)

let duplicateNameHint = SearchEngine.candidateHint(for: SearchRequest(query: "dupe:"))
expect(
    duplicateNameHint.canUseDatabaseCandidates == false,
    "default duplicate-name searches should avoid lossy SQLite candidate prefiltering"
)

let exactDuplicateNameHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "dupe:", options: exactParentChildOptions)
)
expect(
    exactDuplicateNameHint.canUseDatabaseCandidates &&
        exactDuplicateNameHint.numericFilters.first?.field == .nameFrequency,
    "exact duplicate-name searches should be pushed into SQLite candidate hints"
)

let exactUniqueNameHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "dupe:0", options: exactParentChildOptions)
)
expect(
    exactUniqueNameHint.canUseDatabaseCandidates &&
        exactUniqueNameHint.numericFilters.first?.field == .nameFrequency &&
        exactUniqueNameHint.numericFilters.first?.op == .lessThanOrEqual,
    "exact unique-name searches should be pushed into SQLite candidate hints"
)

let namePartDupeHint = SearchEngine.candidateHint(for: SearchRequest(query: "namepartdupe:"))
expect(
    namePartDupeHint.canUseDatabaseCandidates == false,
    "default namepartdupe: searches should avoid lossy SQLite candidate prefiltering"
)

let exactNamePartDupeHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "namepartdupe:", options: exactParentChildOptions)
)
expect(
    exactNamePartDupeHint.canUseDatabaseCandidates &&
        exactNamePartDupeHint.numericFilters.first?.field == .namePartFrequency,
    "exact namepartdupe: searches should be pushed into SQLite candidate hints"
)

let nameFrequencyHint = SearchEngine.candidateHint(for: SearchRequest(query: "name-frequency:>1"))
expect(
    nameFrequencyHint.canUseDatabaseCandidates == false,
    "name-frequency: searches should avoid lossy SQLite candidate prefiltering"
)

let exactNameFrequencyHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "name-frequency:>1", options: exactParentChildOptions)
)
expect(
    exactNameFrequencyHint.canUseDatabaseCandidates &&
        exactNameFrequencyHint.numericFilters.first?.field == .nameFrequency,
    "exact name-frequency: searches should be pushed into SQLite candidate hints"
)

let extensionFrequencyHint = SearchEngine.candidateHint(for: SearchRequest(query: "extension-frequency:>1"))
expect(
    extensionFrequencyHint.canUseDatabaseCandidates == false,
    "extension-frequency: searches should avoid lossy SQLite candidate prefiltering"
)

let exactExtensionFrequencyHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "extension-frequency:>1", options: exactParentChildOptions)
)
expect(
    exactExtensionFrequencyHint.canUseDatabaseCandidates &&
        exactExtensionFrequencyHint.numericFilters.first?.field == .extensionFrequency,
    "exact extension-frequency: searches should be pushed into SQLite candidate hints"
)

let pathDupeHint = SearchEngine.candidateHint(for: SearchRequest(query: "path-dupe:"))
expect(
    pathDupeHint.canUseDatabaseCandidates == false,
    "path-dupe: searches should avoid lossy SQLite candidate prefiltering"
)

let exactPathDupeHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "path-dupe:", options: exactParentChildOptions)
)
expect(
    exactPathDupeHint.canUseDatabaseCandidates &&
        exactPathDupeHint.numericFilters.first?.field == .pathPartFrequency,
    "exact path-dupe: searches should be pushed into SQLite candidate hints"
)

let fileListHint = SearchEngine.candidateHint(for: SearchRequest(query: "filelist:Launch.JPG|Launch Notes.md"))
expect(
    fileListHint.canUseDatabaseCandidates == false,
    "filelist: searches should avoid lossy SQLite candidate prefiltering"
)

let exactFileListNameHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "filelist:readme.txt", options: exactParentChildOptions)
)
expect(
    exactFileListNameHint.canUseDatabaseCandidates &&
        exactFileListNameHint.fileListFilters.first?.nameValues == Set(["readme.txt"]),
    "exact filelist: name searches should be pushed into SQLite candidate hints"
)

let exactFileListPathHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "filelist:/Users/me/project/archive/readme.txt", options: exactParentChildOptions)
)
expect(
    exactFileListPathHint.canUseDatabaseCandidates &&
        exactFileListPathHint.fileListFilters.first?.pathValues == Set(["/Users/me/project/archive/readme.txt"]),
    "exact filelist: path searches should be pushed into SQLite candidate hints"
)

let wildcardFileListHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "filelist:readme.*", options: exactParentChildOptions)
)
expect(
    wildcardFileListHint.canUseDatabaseCandidates == false,
    "wildcard filelist: searches should avoid lossy SQLite candidate prefiltering"
)

let fileListFilenameHint = SearchEngine.candidateHint(for: SearchRequest(query: "filelistfilename:Offline.efu"))
expect(
    fileListFilenameHint.canUseDatabaseCandidates &&
        fileListFilenameHint.requiresFileListSource &&
        fileListFilenameHint.fileListSourceFilters.isEmpty,
    "filelistfilename: searches should be narrowed to file-list source entries"
)

let exactFileListFilenameHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "filelistfilename:Offline.efu", options: exactParentChildOptions)
)
expect(
    exactFileListFilenameHint.canUseDatabaseCandidates &&
        exactFileListFilenameHint.fileListSourceFilters.first?.nameValues == Set(["Offline.efu"]),
    "exact filelistfilename: source names should be pushed into SQLite candidate hints"
)

let exactFileListFilenamePathHint = SearchEngine.candidateHint(
    for: SearchRequest(
        query: "filelistfilename:\"/Users/me/File Lists/Offline.efu\"",
        options: exactParentChildOptions
    )
)
expect(
    exactFileListFilenamePathHint.canUseDatabaseCandidates &&
        exactFileListFilenamePathHint.fileListSourceFilters.first?.pathValues == Set([
            "/Users/me/File Lists/Offline.efu"
        ]),
    "exact filelistfilename: source paths should be pushed into SQLite candidate hints"
)

let fileListFilenameListHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "filelistfilename:Offline.efu;Archive.efu")
)
expect(
    fileListFilenameListHint.canUseDatabaseCandidates &&
        fileListFilenameListHint.requiresFileListSource,
    "filelistfilename: value lists should preserve file-list source candidate filters"
)

let exactFileListFilenameListHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "filelistfilename:Offline.efu;Archive.efu", options: exactParentChildOptions)
)
expect(
    exactFileListFilenameListHint.canUseDatabaseCandidates &&
        exactFileListFilenameListHint.fileListSourceFilters.first?.nameValues == Set([
            "Offline.efu",
            "Archive.efu"
        ]),
    "exact filelistfilename: value lists should be pushed into SQLite source candidate hints"
)

let frnHint = SearchEngine.candidateHint(for: SearchRequest(query: "frn:12345"))
expect(
    frnHint.canUseDatabaseCandidates &&
        frnHint.fileReferenceFilter?.fileID == "12345" &&
        frnHint.fileReferenceFilter?.volumeID == nil,
    "frn: file-id searches should be pushed into SQLite candidate hints"
)

let volumeQualifiedFRNHint = SearchEngine.candidateHint(for: SearchRequest(query: "frn:678:12345"))
expect(
    volumeQualifiedFRNHint.canUseDatabaseCandidates &&
        volumeQualifiedFRNHint.fileReferenceFilter?.fileID == "12345" &&
        volumeQualifiedFRNHint.fileReferenceFilter?.volumeID == "678",
    "volume-qualified frn: searches should be pushed into SQLite candidate hints"
)

let emptyFRNHint = SearchEngine.candidateHint(for: SearchRequest(query: "frn:"))
expect(
    emptyFRNHint.canUseDatabaseCandidates &&
        emptyFRNHint.fileReferenceFilter?.fileID == nil &&
        emptyFRNHint.fileReferenceFilter?.volumeID == nil,
    "empty frn: searches should be pushed into SQLite identity-presence hints"
)

let listedFRNHint = SearchEngine.candidateHint(for: SearchRequest(query: "frn:12345;999"))
expect(
    listedFRNHint.canUseDatabaseCandidates == false,
    "semicolon frn: searches should avoid lossy SQLite candidate prefiltering"
)

let fsiHint = SearchEngine.candidateHint(for: SearchRequest(query: "fsi:0"))
expect(
    fsiHint.canUseDatabaseCandidates == false,
    "fsi: searches should avoid lossy SQLite candidate prefiltering"
)

let mediaTagHint = SearchEngine.candidateHint(for: SearchRequest(query: "artist:Codex"))
expect(
    mediaTagHint.canUseDatabaseCandidates == false,
    "diacritic-insensitive media tag text searches should avoid lossy SQLite text prefiltering"
)

let mediaTagSensitiveHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "artist:Codex", options: SearchOptions(diacriticSensitive: true))
)
expect(
    mediaTagSensitiveHint.canUseDatabaseCandidates &&
        mediaTagSensitiveHint.mediaTextFilters.count == 1 &&
        mediaTagSensitiveHint.mediaTextFilters[0].field == .mediaArtist &&
        mediaTagSensitiveHint.mediaTextFilters[0].value == "Codex",
    "diacritic-sensitive media tag searches should be pushed into SQLite candidate hints"
)

let mediaTagPresenceHint = SearchEngine.candidateHint(for: SearchRequest(query: "artist:"))
expect(
    mediaTagPresenceHint.canUseDatabaseCandidates &&
        mediaTagPresenceHint.mediaTextFilters.count == 1 &&
        mediaTagPresenceHint.mediaTextFilters[0].field == .mediaArtist &&
        mediaTagPresenceHint.mediaTextFilters[0].value.isEmpty,
    "empty media tag searches should be pushed into SQLite presence filters"
)

let mediaTrackHint = SearchEngine.candidateHint(for: SearchRequest(query: "track:>5"))
expect(
    mediaTrackHint.canUseDatabaseCandidates &&
        mediaTrackHint.numericFilters.count == 1 &&
        mediaTrackHint.numericFilters[0].field == .mediaTrack &&
        mediaTrackHint.numericFilters[0].op == .greaterThan &&
        mediaTrackHint.numericFilters[0].value == 5,
    "media track filters should be pushed into SQLite candidate hints"
)

let mediaYearHint = SearchEngine.candidateHint(for: SearchRequest(query: "year:>=2020"))
expect(
    mediaYearHint.canUseDatabaseCandidates &&
        mediaYearHint.numericFilters.count == 1 &&
        mediaYearHint.numericFilters[0].field == .mediaYear &&
        mediaYearHint.numericFilters[0].op == .greaterThanOrEqual &&
        mediaYearHint.numericFilters[0].value == 2020,
    "media year filters should be pushed into SQLite candidate hints"
)

let depthHint = SearchEngine.candidateHint(for: SearchRequest(query: "depth:>=4"))
expect(
    depthHint.canUseDatabaseCandidates &&
        depthHint.numericFilters.count == 1 &&
        depthHint.numericFilters[0].field == .depth &&
        depthHint.numericFilters[0].op == .greaterThanOrEqual &&
        depthHint.numericFilters[0].value == 4,
    "depth filters should be pushed into SQLite candidate hints"
)

let exactParentCountHint = SearchEngine.candidateHint(for: SearchRequest(query: "parent-count:4"))
expect(
    exactParentCountHint.canUseDatabaseCandidates &&
        exactParentCountHint.numericFilters.count == 1 &&
        exactParentCountHint.numericFilters[0].field == .depth &&
        exactParentCountHint.numericFilters[0].op == .equal &&
        exactParentCountHint.numericFilters[0].value == 4,
    "parent-count filters should alias depth SQLite candidate hints"
)

let fileExistsHint = SearchEngine.candidateHint(for: SearchRequest(query: "file-exists:$stem:.jpg"))
expect(
    fileExistsHint.canUseDatabaseCandidates == false,
    "file-exists: searches should avoid lossy SQLite candidate prefiltering"
)

let exactFileExistsHint = SearchEngine.candidateHint(for: SearchRequest(query: "file-exists:Track.jpg"))
expect(
    exactFileExistsHint.canUseDatabaseCandidates &&
        exactFileExistsHint.existsFilters.first?.relativeName == "Track.jpg",
    "exact file-exists: searches should be pushed into SQLite candidate hints"
)

let absoluteExistsHint = SearchEngine.candidateHint(for: SearchRequest(query: "exists:/Users/me/Music/Track.jpg"))
expect(
    absoluteExistsHint.canUseDatabaseCandidates &&
        absoluteExistsHint.existsFilters.first?.pathValue == "/Users/me/Music/Track.jpg",
    "absolute exists: searches should be pushed into SQLite candidate hints"
)

let folderExistsHint = SearchEngine.candidateHint(for: SearchRequest(query: "folder-exists:Archive"))
expect(
    folderExistsHint.canUseDatabaseCandidates &&
        folderExistsHint.existsFilters.first?.allowedKinds == Set<FileKind>([.folder, .package]),
    "exact folder-exists: searches should preserve kind filters in SQLite candidate hints"
)

let wildcardFileExistsHint = SearchEngine.candidateHint(for: SearchRequest(query: "file-exists:*.jpg"))
expect(
    wildcardFileExistsHint.canUseDatabaseCandidates == false,
    "wildcard file-exists: searches should avoid lossy SQLite candidate prefiltering"
)

let pathListHint = SearchEngine.candidateHint(for: SearchRequest(query: "path-list:/Users/me/Pictures/Launch.JPG"))
expect(
    pathListHint.canUseDatabaseCandidates == false,
    "path-list: searches should avoid lossy SQLite candidate prefiltering"
)

let exactPathListHint = SearchEngine.candidateHint(
    for: SearchRequest(
        query: "path-list:/Users/me/Pictures/Launch.JPG",
        options: exactParentChildOptions
    )
)
expect(
    exactPathListHint.canUseDatabaseCandidates &&
        exactPathListHint.pathListFilters.first?.paths == Set(["/Users/me/Pictures/Launch.JPG"]),
    "exact path-list: searches should be pushed into SQLite candidate hints"
)

let exactListedPathListHint = SearchEngine.candidateHint(
    for: SearchRequest(
        query: "path-list:/Users/me/Pictures/Launch.JPG;/Users/me/Documents/Launch",
        options: exactParentChildOptions
    )
)
expect(
    exactListedPathListHint.canUseDatabaseCandidates == false,
    "semicolon path-list: searches should avoid lossy SQLite candidate prefiltering"
)

let substitutionPathListHint = SearchEngine.candidateHint(
    for: SearchRequest(query: "path-list:$path:", options: exactParentChildOptions)
)
expect(
    substitutionPathListHint.canUseDatabaseCandidates == false,
    "substituted path-list: searches should avoid lossy SQLite candidate prefiltering"
)

let nothingHint = SearchEngine.candidateHint(for: SearchRequest(query: "nothing:"))
expect(
    nothingHint.canUseDatabaseCandidates == false,
    "nothing: searches should avoid unnecessary SQLite candidate prefiltering"
)

let emptyHint = SearchEngine.candidateHint(for: SearchRequest(query: "empty:"))
expect(
    emptyHint.canUseDatabaseCandidates &&
        emptyHint.requiresEmptyEntry,
    "empty: searches should be pushed into SQLite candidate hints"
)

let nonEmptyHint = SearchEngine.candidateHint(for: SearchRequest(query: "empty:0"))
expect(
    nonEmptyHint.canUseDatabaseCandidates &&
        nonEmptyHint.requiresNonEmptyEntry,
    "empty:0 searches should be pushed into SQLite candidate hints"
)

let rootHint = SearchEngine.candidateHint(for: SearchRequest(query: "root:"))
expect(
    rootHint.canUseDatabaseCandidates &&
        rootHint.rootOnly,
    "root: searches should be pushed into SQLite candidate hints"
)

let rootFalseHint = SearchEngine.candidateHint(for: SearchRequest(query: "root:0"))
expect(
    rootFalseHint.canUseDatabaseCandidates == false,
    "root:0 searches should avoid unnecessary SQLite candidate prefiltering"
)

let shellHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch shell:desktop"))
expect(
    shellHint.canUseDatabaseCandidates &&
        shellHint.terms == ["launch"] &&
        shellHint.folderTreePaths == [selfTestDesktopPath],
    "known shell: searches should add resolved folder trees to SQLite candidate filters"
)

let shellOnlyHint = SearchEngine.candidateHint(for: SearchRequest(query: "shell:desktop"))
expect(
    shellOnlyHint.canUseDatabaseCandidates &&
        shellOnlyHint.terms.isEmpty &&
        shellOnlyHint.folderTreePaths == [selfTestDesktopPath],
    "shell-only searches should use SQLite folder tree candidate filters"
)

let unknownShellHint = SearchEngine.candidateHint(for: SearchRequest(query: "shell:not-a-real-folder"))
expect(
    unknownShellHint.canUseDatabaseCandidates == false,
    "unknown shell: searches should avoid unnecessary SQLite candidate prefiltering"
)

let imageMetadataHint = SearchEngine.candidateHint(for: SearchRequest(query: "width:2"))
expect(
    imageMetadataHint.canUseDatabaseCandidates == false,
    "image metadata searches should avoid lossy SQLite candidate prefiltering"
)

let bitDepthHint = SearchEngine.candidateHint(for: SearchRequest(query: "bit-depth:>0"))
expect(
    bitDepthHint.canUseDatabaseCandidates == false,
    "bit-depth: searches should avoid lossy SQLite candidate prefiltering"
)

let aspectRatioHint = SearchEngine.candidateHint(for: SearchRequest(query: "aspect-ratio:16:9"))
expect(
    aspectRatioHint.canUseDatabaseCandidates == false,
    "aspect-ratio: searches should avoid lossy SQLite candidate prefiltering"
)

let explicitAndHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch AND notes"))
expect(
    explicitAndHint.canUseDatabaseCandidates && explicitAndHint.terms == ["launch", "notes"],
    "explicit AND should not become a SQLite candidate term"
)

let caseModifierHint = SearchEngine.candidateHint(for: SearchRequest(query: "case:launch"))
expect(
    caseModifierHint.canUseDatabaseCandidates &&
        caseModifierHint.terms == ["launch"],
    "case: modifiers should preserve safe SQLite candidate terms"
)

let fileModifierHint = SearchEngine.candidateHint(for: SearchRequest(query: "file:launch"))
expect(
    fileModifierHint.canUseDatabaseCandidates &&
        fileModifierHint.terms == ["launch"] &&
        fileModifierHint.kinds == [.file, .symlink, .package],
    "file:<term> modifiers should preserve kind and term SQLite candidate hints"
)

let regexModifierHint = SearchEngine.candidateHint(for: SearchRequest(query: "regex:^launch"))
expect(
    regexModifierHint.canUseDatabaseCandidates &&
        regexModifierHint.terms == ["launch"],
    "anchored literal regex modifiers should preserve safe SQLite candidate terms"
)

let regexOptionHint = SearchEngine.candidateHint(for: SearchRequest(query: "^launch", options: SearchOptions(regexMatching: true)))
expect(
    regexOptionHint.canUseDatabaseCandidates &&
        regexOptionHint.terms == ["launch"],
    "anchored literal regex search options should preserve safe SQLite candidate terms"
)

let unsafeRegexHint = SearchEngine.candidateHint(for: SearchRequest(query: "regex:^launch|notes"))
expect(
    unsafeRegexHint.canUseDatabaseCandidates == false,
    "regex alternation should avoid lossy SQLite candidate prefiltering"
)

let encodedContentHint = SearchEngine.candidateHint(for: SearchRequest(query: "utf16content:hello"))
expect(
    encodedContentHint.canUseDatabaseCandidates == false,
    "encoded content searches should avoid lossy SQLite candidate prefiltering"
)

let wildcardModifierHint = SearchEngine.candidateHint(for: SearchRequest(query: "wildcards:launch*"))
expect(
    wildcardModifierHint.canUseDatabaseCandidates == false,
    "wildcard modifiers should avoid lossy SQLite candidate prefiltering"
)

let sortDirectiveHint = SearchEngine.candidateHint(for: SearchRequest(query: "sort:size descending: launch"))
expect(
    sortDirectiveHint.canUseDatabaseCandidates &&
        sortDirectiveHint.terms == ["launch"],
    "sort directives should not become SQLite candidate terms"
)

let offsetDirectiveHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch offset:1"))
expect(
    offsetDirectiveHint.canUseDatabaseCandidates &&
        offsetDirectiveHint.terms == ["launch"],
    "offset directives should not become SQLite candidate terms"
)

let sortedBySize = SearchEngine.search(
    request: SearchRequest(query: "file:", sortField: .size, sortDirection: .descending),
    in: syntaxEntries
)
expect(
    Array(sortedBySize.entries.prefix(2).map(\.path)) == [photo.path, document.path],
    "explicit size sorting should sort files by size"
)

let querySortedBySize = SearchEngine.search(
    request: SearchRequest(query: "sort:size descending: file:"),
    in: syntaxEntries
)
expect(
    Array(querySortedBySize.entries.prefix(2).map(\.path)) == [photo.path, document.path],
    "sort: and descending: query directives should sort files by size"
)

let querySortedByShortSize = SearchEngine.search(
    request: SearchRequest(query: "sort:sz descending: file:"),
    in: syntaxEntries
)
expect(
    Array(querySortedByShortSize.entries.prefix(2).map(\.path)) == [photo.path, document.path],
    "sort:sz should alias sort:size"
)

let offsetAlpha = FileEntry(
    path: "/Users/me/Offsets/Alpha.txt",
    name: "Alpha.txt",
    parent: "/Users/me/Offsets",
    kind: .file,
    byteSize: 1,
    modifiedAt: Date(timeIntervalSince1970: 5_010)
)
let offsetBravo = FileEntry(
    path: "/Users/me/Offsets/Bravo.txt",
    name: "Bravo.txt",
    parent: "/Users/me/Offsets",
    kind: .file,
    byteSize: 1,
    modifiedAt: Date(timeIntervalSince1970: 5_020)
)
let offsetCharlie = FileEntry(
    path: "/Users/me/Offsets/Charlie.txt",
    name: "Charlie.txt",
    parent: "/Users/me/Offsets",
    kind: .file,
    byteSize: 1,
    modifiedAt: Date(timeIntervalSince1970: 5_030)
)
let offsetEntries = [offsetCharlie, offsetAlpha, offsetBravo]

let queryOffsetResults = SearchEngine.search(
    request: SearchRequest(query: "sort:name ascending: file: offset:1", limit: 1),
    in: offsetEntries
)
expect(
    queryOffsetResults.entries.map(\.path) == [offsetBravo.path] &&
        queryOffsetResults.totalMatches == 3,
    "offset: should skip sorted result windows while preserving total matches"
)

let querySkipResults = SearchEngine.search(
    request: SearchRequest(query: "sort:name ascending: file: skip:2", limit: 1),
    in: offsetEntries
)
expect(
    querySkipResults.entries.map(\.path) == [offsetCharlie.path],
    "skip: should alias offset:"
)

let queryFirstResults = SearchEngine.search(
    request: SearchRequest(query: "sort:name ascending: file: first:2", limit: 1),
    in: offsetEntries
)
expect(
    queryFirstResults.entries.map(\.path) == [offsetBravo.path],
    "first: should use a one-based result position"
)

let invalidOffsetDirective = SearchEngine.search(
    request: SearchRequest(query: "offset:nope file:"),
    in: [document, photo]
)
expect(
    invalidOffsetDirective.warnings.contains("Could not parse offset:nope"),
    "invalid offset directives should produce parser warnings"
)

let sortedByExtension = SearchEngine.search(
    request: SearchRequest(query: "file:", sortField: .extensionName, sortDirection: .ascending),
    in: [document, photo]
)
expect(
    sortedByExtension.entries.map(\.path) == [photo.path, document.path],
    "explicit extension sorting should sort by file extension"
)

let querySortedByExtension = SearchEngine.search(
    request: SearchRequest(query: "ascending:extension file:"),
    in: [document, photo]
)
expect(
    querySortedByExtension.entries.map(\.path) == [photo.path, document.path],
    "ascending:<field> query directives should sort by the requested field"
)

let querySortedByDateAlias = SearchEngine.search(
    request: SearchRequest(query: "sort:date descending: file:"),
    in: [document, photo]
)
expect(
    querySortedByDateAlias.entries.map(\.path) == [photo.path, document.path],
    "sort:date should alias date-modified sorting"
)

let querySortedByCreatedDateOnly = SearchEngine.search(
    request: SearchRequest(query: "sort:date-created-date descending: file:"),
    in: [photo, sameNamePartText]
)
expect(
    querySortedByCreatedDateOnly.entries.map(\.path) == [sameNamePartText.path, photo.path],
    "sort:date-created-date should alias date-created sorting"
)

let invalidSortDirective = SearchEngine.search(
    request: SearchRequest(query: "sort:nope file:"),
    in: [document, photo]
)
expect(
    invalidSortDirective.warnings.contains("Could not parse sort:nope"),
    "invalid sort directives should produce parser warnings"
)

let sortedByAttributes = SearchEngine.search(
    request: SearchRequest(query: "", sortField: .attributes, sortDirection: .ascending),
    in: [readonlyEntry, hiddenEntry]
)
expect(
    sortedByAttributes.entries.map(\.path) == [hiddenEntry.path, readonlyEntry.path],
    "explicit attribute sorting should sort by EFU-style attribute strings"
)

let sortedByAttributeAlias = SearchEngine.search(
    request: SearchRequest(query: "sort:attribute", sortDirection: .ascending),
    in: [readonlyEntry, hiddenEntry]
)
expect(
    sortedByAttributeAlias.entries.map(\.path) == [hiddenEntry.path, readonlyEntry.path],
    "sort:attribute should alias attributes sorting"
)

let launchedTwice = photo.recordingRun(at: Date(timeIntervalSince1970: 4_000))
    .recordingRun(at: Date(timeIntervalSince1970: 5_000))
let launchedOnce = document.recordingRun(at: Date(timeIntervalSince1970: 3_000))
let sortedByRunCount = SearchEngine.search(
    request: SearchRequest(query: "file:", sortField: .runCount, sortDirection: .descending),
    in: [launchedOnce, launchedTwice]
)
expect(
    sortedByRunCount.entries.map(\.path) == [launchedTwice.path, launchedOnce.path],
    "run count sorting should prefer frequently opened results"
)

expect(
    SearchEngine.search(query: "runcount:>1", in: [launchedOnce, launchedTwice]).map(\.path) == [launchedTwice.path],
    "runcount: should compare recorded launch counts"
)

expect(
    SearchEngine.search(query: "run-count:>1", in: [launchedOnce, launchedTwice]).map(\.path) == [launchedTwice.path],
    "dashed run-count aliases should compare recorded launch counts"
)

expect(
    Set(SearchEngine.search(query: "dr:1970-01-01", in: [launchedOnce, launchedTwice]).map(\.path)) ==
        Set([launchedOnce.path, launchedTwice.path]),
    "dr: should filter by recorded launch date"
)

expect(
    Set(SearchEngine.search(query: "date-run:1970-01-01", in: [launchedOnce, launchedTwice]).map(\.path)) ==
        Set([launchedOnce.path, launchedTwice.path]),
    "dashed date-run aliases should filter by recorded launch date"
)

let dateSyntaxNow = Date()
let dateSyntaxCalendar = Calendar.current
let dateSyntaxWeek = dateSyntaxCalendar.dateInterval(of: .weekOfYear, for: dateSyntaxNow)!
let dateSyntaxMonth = dateSyntaxCalendar.dateInterval(of: .month, for: dateSyntaxNow)!
let dateSyntaxYear = dateSyntaxCalendar.dateInterval(of: .year, for: dateSyntaxNow)!
let dateSyntaxQuarterComponents = dateSyntaxCalendar.dateComponents([.year, .month], from: dateSyntaxNow)
let dateSyntaxQuarterStartMonth = ((dateSyntaxQuarterComponents.month! - 1) / 3) * 3 + 1
let dateSyntaxQuarterStart = dateSyntaxCalendar.date(
    from: DateComponents(
        year: dateSyntaxQuarterComponents.year!,
        month: dateSyntaxQuarterStartMonth,
        day: 1
    )
)!
let dateSyntaxQuarterEnd = dateSyntaxCalendar.date(byAdding: .month, value: 3, to: dateSyntaxQuarterStart)!
let relativeRecent = FileEntry(
    path: "/Users/me/Dates/Recent.txt",
    name: "Recent.txt",
    parent: "/Users/me/Dates",
    kind: .file,
    byteSize: 10,
    modifiedAt: Calendar.current.date(byAdding: .day, value: -1, to: dateSyntaxNow)!
)
let relativeOlder = FileEntry(
    path: "/Users/me/Dates/Older.txt",
    name: "Older.txt",
    parent: "/Users/me/Dates",
    kind: .file,
    byteSize: 10,
    modifiedAt: Calendar.current.date(byAdding: .day, value: -3, to: dateSyntaxNow)!
)
let currentPeriodEntry = FileEntry(
    path: "/Users/me/Dates/CurrentPeriod.txt",
    name: "CurrentPeriod.txt",
    parent: "/Users/me/Dates",
    kind: .file,
    byteSize: 10,
    modifiedAt: dateSyntaxNow
)
let previousMonthEntry = FileEntry(
    path: "/Users/me/Dates/PreviousMonth.txt",
    name: "PreviousMonth.txt",
    parent: "/Users/me/Dates",
    kind: .file,
    byteSize: 10,
    modifiedAt: dateSyntaxCalendar.date(byAdding: .day, value: -1, to: dateSyntaxMonth.start)!
)
let previousQuarterEntry = FileEntry(
    path: "/Users/me/Dates/PreviousQuarter.txt",
    name: "PreviousQuarter.txt",
    parent: "/Users/me/Dates",
    kind: .file,
    byteSize: 10,
    modifiedAt: dateSyntaxCalendar.date(byAdding: .day, value: -1, to: dateSyntaxQuarterStart)!
)
let previousYearEntry = FileEntry(
    path: "/Users/me/Dates/PreviousYear.txt",
    name: "PreviousYear.txt",
    parent: "/Users/me/Dates",
    kind: .file,
    byteSize: 10,
    modifiedAt: dateSyntaxCalendar.date(byAdding: .day, value: -1, to: dateSyntaxYear.start)!
)
let previousWeekEntry = FileEntry(
    path: "/Users/me/Dates/PreviousWeek.txt",
    name: "PreviousWeek.txt",
    parent: "/Users/me/Dates",
    kind: .file,
    byteSize: 10,
    modifiedAt: dateSyntaxCalendar.date(byAdding: .day, value: -1, to: dateSyntaxWeek.start)!
)
let futureRelativeEntry = FileEntry(
    path: "/Users/me/Dates/FutureRelative.txt",
    name: "FutureRelative.txt",
    parent: "/Users/me/Dates",
    kind: .file,
    byteSize: 10,
    modifiedAt: Calendar.current.date(byAdding: .hour, value: 1, to: dateSyntaxNow)!
)
let nextWeekEntry = FileEntry(
    path: "/Users/me/Dates/NextWeek.txt",
    name: "NextWeek.txt",
    parent: "/Users/me/Dates",
    kind: .file,
    byteSize: 10,
    modifiedAt: dateSyntaxCalendar.date(
        byAdding: .hour,
        value: 1,
        to: dateSyntaxWeek.end
    )!
)
let nextMonthEntry = FileEntry(
    path: "/Users/me/Dates/NextMonth.txt",
    name: "NextMonth.txt",
    parent: "/Users/me/Dates",
    kind: .file,
    byteSize: 10,
    modifiedAt: dateSyntaxCalendar.date(
        byAdding: .day,
        value: 1,
        to: dateSyntaxMonth.end
    )!
)
let nextYearEntry = FileEntry(
    path: "/Users/me/Dates/NextYear.txt",
    name: "NextYear.txt",
    parent: "/Users/me/Dates",
    kind: .file,
    byteSize: 10,
    modifiedAt: dateSyntaxCalendar.date(
        byAdding: .day,
        value: 1,
        to: dateSyntaxYear.end
    )!
)
let nextQuarterEntry = FileEntry(
    path: "/Users/me/Dates/NextQuarter.txt",
    name: "NextQuarter.txt",
    parent: "/Users/me/Dates",
    kind: .file,
    byteSize: 10,
    modifiedAt: dateSyntaxCalendar.date(
        byAdding: .day,
        value: 1,
        to: dateSyntaxQuarterEnd
    )!
)
let dateConstantFormatter = DateFormatter()
dateConstantFormatter.locale = Locale(identifier: "en_US_POSIX")
dateConstantFormatter.dateFormat = "MMMM"
let currentMonthName = dateConstantFormatter.string(from: dateSyntaxNow).lowercased()
dateConstantFormatter.dateFormat = "EEEE"
let currentWeekdayName = dateConstantFormatter.string(from: dateSyntaxNow).lowercased()

expect(
    SearchEngine.search(query: "dm:2days", in: [relativeRecent, relativeOlder]).map(\.path) == [relativeRecent.path],
    "date syntax should accept Everything-style relative values without a last prefix"
)

expect(
    SearchEngine.search(query: "dm:past2days", in: [relativeRecent, relativeOlder]).map(\.path) == [relativeRecent.path],
    "date syntax should support past-prefixed relative intervals"
)

expect(
    SearchEngine.search(query: "dm:last2days", in: [relativeRecent, relativeOlder]).map(\.path) == [relativeRecent.path],
    "date syntax should support last-prefixed relative intervals"
)

expect(
    SearchEngine.search(query: "dm:prev2days", in: [relativeRecent, relativeOlder]).map(\.path) == [relativeRecent.path],
    "date syntax should support prev-prefixed relative intervals"
)

expect(
    SearchEngine.search(query: "dm:next2hours", in: [currentPeriodEntry, futureRelativeEntry]).map(\.path) == [futureRelativeEntry.path],
    "date syntax should support next-prefixed future relative intervals"
)

expect(
    SearchEngine.search(query: "dm:coming2hours", in: [currentPeriodEntry, futureRelativeEntry]).map(\.path) == [futureRelativeEntry.path],
    "date syntax should support coming-prefixed future relative intervals"
)

expect(
    SearchEngine.search(query: "dm:unknown", in: [relativeRecent, compactMatch]).map(\.path) == [compactMatch.path],
    "date syntax should support unknown dates"
)

expect(
    SearchEngine.search(query: "dm:mtd", in: [currentPeriodEntry, previousMonthEntry]).map(\.path) == [currentPeriodEntry.path],
    "date syntax should support month-to-date"
)

expect(
    SearchEngine.search(query: "dm:qtd", in: [currentPeriodEntry, previousQuarterEntry]).map(\.path) == [currentPeriodEntry.path],
    "date syntax should support quarter-to-date"
)

expect(
    SearchEngine.search(query: "dm:ytd", in: [currentPeriodEntry, previousYearEntry]).map(\.path) == [currentPeriodEntry.path],
    "date syntax should support year-to-date"
)

expect(
    SearchEngine.search(query: "dm:lastweek", in: [currentPeriodEntry, previousWeekEntry]).map(\.path) == [previousWeekEntry.path],
    "date syntax should support previous calendar week intervals"
)

expect(
    SearchEngine.search(query: "dm:currentweek", in: [currentPeriodEntry, previousWeekEntry]).map(\.path) == [currentPeriodEntry.path],
    "date syntax should support current-prefixed calendar intervals"
)

expect(
    SearchEngine.search(query: "dm:thisweek", in: [currentPeriodEntry, previousWeekEntry]).map(\.path) == [currentPeriodEntry.path],
    "date syntax should support this-prefixed calendar intervals"
)

expect(
    SearchEngine.search(query: "dm:pastweek", in: [currentPeriodEntry, previousWeekEntry]).map(\.path) == [previousWeekEntry.path],
    "date syntax should support past-prefixed calendar intervals"
)

expect(
    SearchEngine.search(query: "dm:comingweek", in: [currentPeriodEntry, nextWeekEntry]).map(\.path) == [nextWeekEntry.path],
    "date syntax should support coming-prefixed calendar intervals"
)

expect(
    SearchEngine.search(query: "dm:lastmonth", in: [currentPeriodEntry, previousMonthEntry]).map(\.path) == [previousMonthEntry.path],
    "date syntax should support previous calendar month intervals"
)

expect(
    SearchEngine.search(query: "dm:thismonth", in: [currentPeriodEntry, previousMonthEntry]).map(\.path) == [currentPeriodEntry.path],
    "date syntax should support this-prefixed month intervals"
)

expect(
    SearchEngine.search(query: "dm:currentmonth", in: [currentPeriodEntry, previousMonthEntry]).map(\.path) == [currentPeriodEntry.path],
    "date syntax should support current-prefixed month intervals"
)

expect(
    SearchEngine.search(query: "dm:prevmonth", in: [currentPeriodEntry, previousMonthEntry]).map(\.path) == [previousMonthEntry.path],
    "date syntax should support prev-prefixed calendar intervals"
)

expect(
    SearchEngine.search(query: "dm:comingmonth", in: [currentPeriodEntry, nextMonthEntry]).map(\.path) == [nextMonthEntry.path],
    "date syntax should support coming-prefixed month intervals"
)

expect(
    SearchEngine.search(query: "dm:nextmonth", in: [currentPeriodEntry, nextMonthEntry]).map(\.path) == [nextMonthEntry.path],
    "date syntax should support next-prefixed calendar month intervals"
)

expect(
    SearchEngine.search(query: "dm:lastquarter", in: [currentPeriodEntry, previousQuarterEntry]).map(\.path) == [previousQuarterEntry.path],
    "date syntax should support previous calendar quarter intervals"
)

expect(
    SearchEngine.search(query: "dm:currentqtr", in: [currentPeriodEntry, previousQuarterEntry]).map(\.path) == [currentPeriodEntry.path],
    "date syntax should support current quarter aliases"
)

expect(
    SearchEngine.search(query: "dm:nextquarter", in: [currentPeriodEntry, nextQuarterEntry]).map(\.path) == [nextQuarterEntry.path],
    "date syntax should support next-prefixed calendar quarter intervals"
)

expect(
    SearchEngine.search(query: "dm:nextqtr", in: [currentPeriodEntry, nextQuarterEntry]).map(\.path) == [nextQuarterEntry.path],
    "date syntax should support short next quarter aliases"
)

expect(
    SearchEngine.search(query: "dm:lastyear", in: [currentPeriodEntry, previousYearEntry]).map(\.path) == [previousYearEntry.path],
    "date syntax should support previous calendar year intervals"
)

expect(
    SearchEngine.search(query: "dm:thisyear", in: [currentPeriodEntry, previousYearEntry]).map(\.path) == [currentPeriodEntry.path],
    "date syntax should support this-prefixed year intervals"
)

expect(
    SearchEngine.search(query: "dm:currentyear", in: [currentPeriodEntry, previousYearEntry]).map(\.path) == [currentPeriodEntry.path],
    "date syntax should support current-prefixed year intervals"
)

expect(
    SearchEngine.search(query: "dm:previousyear", in: [currentPeriodEntry, previousYearEntry]).map(\.path) == [previousYearEntry.path],
    "date syntax should support previous-prefixed calendar intervals"
)

expect(
    SearchEngine.search(query: "dm:comingyear", in: [currentPeriodEntry, nextYearEntry]).map(\.path) == [nextYearEntry.path],
    "date syntax should support coming-prefixed year intervals"
)

expect(
    SearchEngine.search(query: "dm:nextyear", in: [currentPeriodEntry, nextYearEntry]).map(\.path) == [nextYearEntry.path],
    "date syntax should support next-prefixed calendar year intervals"
)

expect(
    SearchEngine.search(query: "dm:\(currentMonthName)", in: [currentPeriodEntry, previousYearEntry]).map(\.path) == [currentPeriodEntry.path],
    "date syntax should support month-name constants"
)

expect(
    SearchEngine.search(query: "dm:\(currentWeekdayName)", in: [currentPeriodEntry, previousWeekEntry]).map(\.path) == [currentPeriodEntry.path],
    "date syntax should support weekday-name constants"
)

expect(
    SearchEngine.search(query: "dm:2024", in: [childMetadataFile, document]).map(\.path) == [childMetadataFile.path],
    "date syntax should treat a bare year as a year interval"
)

expect(
    SearchEngine.search(query: "dm:2024-05", in: [childMetadataFile, childMetadataFolder]).map(\.path) == [childMetadataFile.path],
    "date syntax should treat YYYY-MM as a month interval"
)

expect(
    SearchEngine.search(query: "dm:2024/05", in: [childMetadataFile, childMetadataFolder]).map(\.path) == [childMetadataFile.path],
    "date syntax should treat YYYY/MM as a month interval"
)

expect(
    SearchEngine.search(query: "dm:05/2024", in: [childMetadataFile, childMetadataFolder]).map(\.path) == [childMetadataFile.path],
    "date syntax should treat MM/YYYY as a month interval"
)

expect(
    SearchEngine.search(query: "dm:5/2024", in: [childMetadataFile, childMetadataFolder]).map(\.path) == [childMetadataFile.path],
    "date syntax should support unpadded month/year intervals"
)

expect(
    SearchEngine.search(query: "dm:202405", in: [childMetadataFile, childMetadataFolder]).map(\.path) == [childMetadataFile.path],
    "date syntax should treat compact YYYYMM as a month interval"
)

expect(
    SearchEngine.search(query: "dm:20240502", in: [childMetadataFile, childMetadataFolder]).map(\.path) == [childMetadataFile.path],
    "date syntax should support compact YYYYMMDD dates"
)

expect(
    SearchEngine.search(query: "dm:2024-05-02T12:00", in: [childMetadataFile, childMetadataFolder]).map(\.path) == [childMetadataFile.path],
    "date syntax should support ISO datetime minute precision"
)

expect(
    SearchEngine.search(query: "dm:20240502T120000", in: [childMetadataFile, childMetadataFolder]).map(\.path) == [childMetadataFile.path],
    "date syntax should support compact ISO datetime second precision"
)

expect(
    SearchEngine.search(query: "dm:2024-05-*", in: [childMetadataFile, childMetadataFolder]).map(\.path) == [childMetadataFile.path],
    "date syntax should support wildcard day components"
)

expect(
    SearchEngine.search(query: "dm:2024-?5-02", in: [childMetadataFile, childMetadataFolder]).map(\.path) == [childMetadataFile.path],
    "date syntax should support wildcard month components"
)

expect(
    SearchEngine.search(query: "dm:202405??", in: [childMetadataFile, childMetadataFolder]).map(\.path) == [childMetadataFile.path],
    "date syntax should support compact wildcard dates"
)

expect(
    SearchEngine.search(query: "dm:2024-05-02t12:*", in: [childMetadataFile, childMetadataFolder]).map(\.path) == [childMetadataFile.path],
    "date syntax should support wildcard datetime components"
)

expect(
    SearchEngine.search(query: "date-modified:>2000-01-01", in: [photo, document]).map(\.path) == [photo.path],
    "dashed date-modified aliases should filter by modified date"
)

expect(
    SearchEngine.search(query: "date-modified-date:>2000-01-01", in: [photo, document]).map(\.path) == [photo.path],
    "date-modified-date: should alias date-modified:"
)

expect(
    SearchEngine.search(query: "date:>2000-01-01", in: [photo, document]).map(\.path) == [photo.path],
    "date: should alias date-modified:"
)

expect(
    SearchEngine.search(query: "date-created-date:1970-01-01", in: [sameNamePartText, document]).map(\.path) == [sameNamePartText.path],
    "date-created-date: should alias date-created:"
)

expect(
    SearchEngine.search(query: "date-accessed-date:1970-01-01", in: [sameNamePartText, document]).map(\.path) == [sameNamePartText.path],
    "date-accessed-date: should alias date-accessed:"
)

let formulaDate = Date(timeIntervalSince1970: 9_100)
let formulaMatchingDates = FileEntry(
    path: "/Users/me/Formulas/MatchingDates.txt",
    name: "MatchingDates.txt",
    parent: "/Users/me/Formulas",
    kind: .file,
    byteSize: 10,
    createdAt: formulaDate,
    modifiedAt: formulaDate
)
let formulaDifferentDates = FileEntry(
    path: "/Users/me/Formulas/DifferentDates.txt",
    name: "DifferentDates.txt",
    parent: "/Users/me/Formulas",
    kind: .file,
    byteSize: 10,
    createdAt: formulaDate,
    modifiedAt: Date(timeIntervalSince1970: 9_200)
)
let formulaAlpha = FileEntry(
    path: "/Users/me/Formulas/Alpha.txt",
    name: "Alpha.txt",
    parent: "/Users/me/Formulas",
    kind: .file,
    byteSize: 10,
    modifiedAt: Date(timeIntervalSince1970: 9_300)
)
let formulaOdin = FileEntry(
    path: "/Users/me/Formulas/Oolong.txt",
    name: "Oolong.txt",
    parent: "/Users/me/Formulas",
    kind: .file,
    byteSize: 10,
    modifiedAt: Date(timeIntervalSince1970: 9_400)
)
let formulaZen = FileEntry(
    path: "/Users/me/Formulas/Zen.txt",
    name: "Zen.txt",
    parent: "/Users/me/Formulas",
    kind: .file,
    byteSize: 10,
    modifiedAt: Date(timeIntervalSince1970: 9_500)
)
let formulaModuloMatch = FileEntry(
    path: "/Users/me/Formulas/abcdef.txt",
    name: "abcdef.txt",
    parent: "/Users/me/Formulas",
    kind: .file,
    byteSize: 10,
    modifiedAt: Date(timeIntervalSince1970: 9_600)
)
let formulaModuloMiss = FileEntry(
    path: "/Users/me/Formulas/abcde.txt",
    name: "abcde.txt",
    parent: "/Users/me/Formulas",
    kind: .file,
    byteSize: 10,
    modifiedAt: Date(timeIntervalSince1970: 9_700)
)

expect(
    SearchEngine.search(
        query: "$date-modified:==$date-created:",
        in: [formulaMatchingDates, formulaDifferentDates]
    ).map(\.path) == [formulaMatchingDates.path],
    "formula search should compare current-entry date properties"
)

expect(
    SearchEngine.search(
        query: "UPPER($name:)>=N UPPER($name:)<=S",
        in: [formulaAlpha, formulaOdin, formulaZen]
    ).map(\.path) == [formulaOdin.path],
    "formula search should support string functions and comparisons"
)

expect(
    SearchEngine.search(
        query: "$name:[1]=='o'",
        in: [formulaAlpha, formulaOdin]
    ).map(\.path) == [formulaOdin.path],
    "formula search should support zero-based string indexing"
)

expect(
    SearchEngine.search(
        query: "len($stem:)%3==0",
        in: [formulaModuloMatch, formulaModuloMiss]
    ).map(\.path) == [formulaModuloMatch.path],
    "formula search should support len() with modulo comparisons"
)

expect(
    SearchEngine.search(
        query: "CONTAINS($name:,'ool')",
        in: [formulaAlpha, formulaOdin]
    ).map(\.path) == [formulaOdin.path],
    "formula search should support CONTAINS()"
)

expect(
    SearchEngine.search(
        query: "STARTSWITH(UPPER($name:),OO)",
        in: [formulaAlpha, formulaOdin]
    ).map(\.path) == [formulaOdin.path],
    "formula search should support STARTSWITH() with nested value functions"
)

expect(
    SearchEngine.search(
        query: "LEFT($name:,3)==Ool RIGHT($stem:,3)==ong MID($name:,1,2)==ol",
        in: [formulaAlpha, formulaOdin]
    ).map(\.path) == [formulaOdin.path],
    "formula search should support LEFT(), RIGHT(), and MID()"
)

expect(
    SearchEngine.search(
        query: "$size:+2==12 $size:/2==5",
        in: [formulaAlpha, formulaOdin]
    ).map(\.path) == [formulaAlpha.path, formulaOdin.path],
    "formula search should support arithmetic operators"
)

expect(
    SearchEngine.search(
        query: "YEAR($date-modified:)==2024 MONTH($date-modified:)==5 DAY($date-modified:)==2 HOUR($date-modified:)==12",
        in: [childMetadataFile, childMetadataFolder]
    ).map(\.path) == [childMetadataFile.path],
    "formula search should support date component functions"
)

expect(
    SearchEngine.search(
        query: "ABS($size:-12)==2 ROUND($size:/3)==3",
        in: [formulaAlpha, formulaOdin]
    ).map(\.path) == [formulaAlpha.path, formulaOdin.path],
    "formula search should support ABS() and ROUND()"
)

expect(
    SearchEngine.search(
        query: "$parent-name:==Formulas $depth:==3 LEN($name:)==10",
        in: [formulaAlpha, formulaOdin]
    ).map(\.path) == [formulaOdin.path],
    "formula search should support parent, depth, and length property aliases"
)

expect(
    SearchEngine.search(
        query: "$attributes:==H $extension-length:==3",
        in: [sameNamePartText, sameNamePartMarkdown]
    ).map(\.path) == [sameNamePartText.path],
    "formula search should support attribute and extension length property aliases"
)

expect(
    SearchEngine.search(
        query: "$child-count:==2 $child-file-count:==1 $child-folder-count:==1",
        in: [folder, childInFolder, childFolderInFolder, nestedGrandchild]
    ).map(\.path) == [folder.path],
    "formula search should support direct child count property aliases"
)

expect(
    SearchEngine.search(
        query: "$descendant-count:==3 $descendant-file-count:==2 $descendant-folder-count:==1",
        in: [folder, childInFolder, childFolderInFolder, nestedGrandchild]
    ).map(\.path) == [folder.path],
    "formula search should support descendant count property aliases"
)

expect(
    Set(SearchEngine.search(
        query: "$sibling-count:==2 $sibling-folder-count:==1",
        in: syntaxEntries
    ).map(\.path)) == Set([document.path, emptyFile.path]),
    "formula search should support sibling count property aliases"
)

expect(
    SearchEngine.search(
        query: "EXISTS('/Users/me/Formulas/Oolong.txt')",
        in: [formulaAlpha, formulaOdin]
    ).map(\.path) == [formulaAlpha.path, formulaOdin.path],
    "formula search should support EXISTS() against indexed paths"
)

expect(
    SearchEngine.search(
        query: "!EXISTS('/Users/me/Formulas/Missing.txt')",
        in: [formulaAlpha, formulaOdin]
    ).map(\.path) == [formulaAlpha.path, formulaOdin.path],
    "formula search should support negated EXISTS()"
)

let exported = ResultExporter.csv(entries: [
    FileEntry(
        path: "/Users/me/Documents/Comma, Quote \" Test.txt",
        name: "Comma, Quote \" Test.txt",
        parent: "/Users/me/Documents",
        kind: .file,
        byteSize: 42,
        modifiedAt: nil
    )
])
expect(
    exported.contains("\"Comma, Quote \"\" Test.txt\""),
    "CSV export should escape commas and quotes"
)

let efu = ResultExporter.efu(entries: [folder, photo])
let parsedFileList = FileListCodec.parseEFU(efu)
expect(
    parsedFileList.map(\.path) == [folder.path, photo.path],
    "EFU-like file lists should round-trip paths"
)
expect(
    parsedFileList.first?.kind == .folder,
    "EFU-like file lists should preserve directory attributes"
)

let attributeRows = ResultExporter.rows(entries: [hiddenEntry, readonlyEntry], columns: [.name, .attributes])
expect(
    attributeRows.map { $0["attributes"] } == ["H", "R"],
    "export rows should include EFU-style attribute strings"
)

let extendedAttributeRows = ResultExporter.rows(entries: [extendedAttributeEntry], columns: [.name, .attributes])
expect(
    extendedAttributeRows.first?["attributes"] == "CEINOPT",
    "export rows should include extended Everything-style attribute constants"
)

let mediaRows = ResultExporter.rows(entries: [mediaTaggedEntry], columns: [.title, .artist, .album, .comment, .genre, .track, .year])
expect(
    mediaRows.first?["title"] == mediaTaggedEntry.mediaTitle &&
        mediaRows.first?["artist"] == mediaTaggedEntry.mediaArtist &&
        mediaRows.first?["album"] == mediaTaggedEntry.mediaAlbum &&
        mediaRows.first?["comment"] == mediaTaggedEntry.mediaComment &&
        mediaRows.first?["genre"] == mediaTaggedEntry.mediaGenre &&
        mediaRows.first?["track"] == "7" &&
        mediaRows.first?["year"] == "2026",
    "export rows should include media tag columns"
)

let extensionRows = ResultExporter.rows(entries: [photo], columns: [.name, .extensionName])
expect(
    extensionRows.first?["extension"] == "JPG",
    "export rows should include extension values"
)

let attributeEFU = ResultExporter.efu(entries: [hiddenEntry, readonlyEntry, symlinkEntry, packageEntry, extendedAttributeEntry])
let parsedAttributeFileList = FileListCodec.parseEFU(attributeEFU)
expect(
    parsedAttributeFileList.first?.attributes.contains(.hidden) == true &&
        parsedAttributeFileList.dropFirst().first?.attributes.contains(.readonly) == true,
    "EFU-like file lists should round-trip hidden and readonly attributes"
)
expect(
    parsedAttributeFileList.first { $0.path == symlinkEntry.path }?.kind == .symlink &&
        parsedAttributeFileList.first { $0.path == packageEntry.path }?.kind == .folder,
    "EFU-like file lists should preserve symlink attributes and treat packages as directories"
)
expect(
    parsedAttributeFileList.first { $0.path == extendedAttributeEntry.path }?.attributes.contains([
        .compressed,
        .encrypted,
        .notContentIndexed,
        .normal,
        .offline,
        .sparse,
        .temporary
    ]) == true,
    "EFU-like file lists should round-trip extended Everything attribute constants"
)

let mountedVolumes = VolumeProfileProvider.mountedVolumes()
expect(
    mountedVolumes.contains { $0.path == "/" },
    "volume profiles should include the root volume"
)
let networkVolume = VolumeProfile(
    id: "smb-share",
    name: "Team Share",
    path: "/Volumes/Team Share",
    isLocal: false,
    isInternal: false,
    isRemovable: false,
    capacity: nil,
    availableCapacity: nil
)
expect(
    networkVolume.requiresIndexConfirmation &&
        networkVolume.locationDescription == "Network" &&
        networkVolume.indexConfirmationMessage.contains("never indexed automatically") &&
        networkVolume.indexConfirmationMessage.contains("Choose it again"),
    "network volume profiles should require explicit indexing confirmation"
)
let externalVolume = VolumeProfile(
    id: "usb-ssd",
    name: "USB SSD",
    path: "/Volumes/USB SSD",
    isLocal: true,
    isInternal: false,
    isRemovable: true,
    capacity: 1_000_000_000,
    availableCapacity: 250_000_000
)
expect(
    externalVolume.requiresIndexConfirmation &&
        externalVolume.locationDescription == "Removable" &&
        externalVolume.menuTitle.contains("free of"),
    "removable volume profiles should require explicit indexing confirmation and show capacity"
)
let internalVolume = VolumeProfile(
    id: "system",
    name: "System",
    path: "/",
    isLocal: true,
    isInternal: true,
    isRemovable: false,
    capacity: nil,
    availableCapacity: nil
)
expect(
    !internalVolume.requiresIndexConfirmation &&
        internalVolume.locationDescription == "Internal",
    "internal volume profiles should not require the extra volume confirmation"
)

let previousPersistentEntry = document.recordingRun(at: Date(timeIntervalSince1970: 7_000))
let reindexedPersistentEntry = FileEntry(
    path: previousPersistentEntry.path,
    name: previousPersistentEntry.name,
    parent: previousPersistentEntry.parent,
    kind: previousPersistentEntry.kind,
    byteSize: previousPersistentEntry.byteSize,
    createdAt: previousPersistentEntry.createdAt,
    modifiedAt: previousPersistentEntry.modifiedAt,
    accessedAt: previousPersistentEntry.accessedAt,
    indexedAt: Date(timeIntervalSince1970: 8_000),
    runCount: previousPersistentEntry.runCount,
    lastRunAt: previousPersistentEntry.lastRunAt,
    attributes: previousPersistentEntry.attributes,
    fileID: previousPersistentEntry.fileID,
    volumeID: previousPersistentEntry.volumeID,
    mediaTitle: previousPersistentEntry.mediaTitle,
    mediaArtist: previousPersistentEntry.mediaArtist,
    mediaAlbum: previousPersistentEntry.mediaAlbum,
    mediaComment: previousPersistentEntry.mediaComment,
    mediaGenre: previousPersistentEntry.mediaGenre,
    mediaTrack: previousPersistentEntry.mediaTrack,
    mediaYear: previousPersistentEntry.mediaYear
)
expect(
    reindexedPersistentEntry.hasSamePersistentCatalogState(as: previousPersistentEntry),
    "persistent catalog state should ignore indexedAt-only rescans"
)

let changedPersistentEntry = FileEntry(
    path: previousPersistentEntry.path,
    name: previousPersistentEntry.name,
    parent: previousPersistentEntry.parent,
    kind: previousPersistentEntry.kind,
    byteSize: 9_999,
    createdAt: previousPersistentEntry.createdAt,
    modifiedAt: previousPersistentEntry.modifiedAt,
    accessedAt: previousPersistentEntry.accessedAt,
    indexedAt: Date(timeIntervalSince1970: 8_100),
    runCount: previousPersistentEntry.runCount,
    lastRunAt: previousPersistentEntry.lastRunAt,
    attributes: previousPersistentEntry.attributes,
    fileID: previousPersistentEntry.fileID,
    volumeID: previousPersistentEntry.volumeID
)
let newPersistentEntry = FileEntry(
    path: "/Users/me/Documents/New Persistent.md",
    name: "New Persistent.md",
    parent: "/Users/me/Documents",
    kind: .file,
    byteSize: 32,
    modifiedAt: Date(timeIntervalSince1970: 8_200),
    indexedAt: Date(timeIntervalSince1970: 8_200)
)
let persistenceDelta = IndexPersistenceDelta.pruned(
    upsertedEntries: [reindexedPersistentEntry, changedPersistentEntry, newPersistentEntry],
    removedPaths: [reindexedPersistentEntry.path, changedPersistentEntry.path, "/Users/me/Documents/Old Persistent.md"],
    existingEntriesByPath: [previousPersistentEntry.path: previousPersistentEntry]
)
expect(
    persistenceDelta.removedPaths == ["/Users/me/Documents/Old Persistent.md"] &&
        persistenceDelta.upsertedEntries.map(\.path) == [changedPersistentEntry.path, newPersistentEntry.path],
    "incremental persistence should prune unchanged rescans and same-path delete/upsert churn"
)

do {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appending(path: "MacThingSelfTest-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    let changedFile = temporaryDirectory.appending(path: "Indexed.txt")
    try Data("hello".utf8).write(to: changedFile)
    let utf16ContentFile = temporaryDirectory.appending(path: "UTF16.txt")
    let utf16ContentData = "wide hello".data(using: .utf16LittleEndian) ?? Data()
    try utf16ContentData.write(to: utf16ContentFile)
    let utf16BEContentFile = temporaryDirectory.appending(path: "UTF16BE.txt")
    let utf16BEContentData = "big hello".data(using: .utf16BigEndian) ?? Data()
    try utf16BEContentData.write(to: utf16BEContentFile)
    let ansiContentFile = temporaryDirectory.appending(path: "ANSI.txt")
    let ansiContentData = Data([0x63, 0x61, 0x66, 0xE9])
    try ansiContentData.write(to: ansiContentFile)

    let changedEntries = FileScanner.scanChangedPath(
        path: temporaryDirectory.path,
        existingEntriesByPath: [:]
    )
    let canonicalTemporaryDirectoryPath = canonicalPath(temporaryDirectory.path)
    let canonicalChangedFilePath = canonicalPath(changedFile.path)
    expect(
        changedEntries.contains { $0.path == canonicalTemporaryDirectoryPath } &&
            changedEntries.contains { $0.path == canonicalChangedFilePath },
        "scanChangedPath should include the changed directory and its child files"
    )

    let changedFileEntry = changedEntries.first { $0.path == canonicalChangedFilePath }
    expect(
        changedFileEntry != nil,
        "changed file should be indexed for content search"
    )
    let contentResults = SearchEngine.search(query: "content:hello", in: changedFileEntry.map { [$0] } ?? [])
    expect(
        contentResults.first?.path == canonicalChangedFilePath,
        "content: should search small UTF-8 text files explicitly"
    )

    let utf16ContentEntry = FileEntry(
        path: canonicalPath(utf16ContentFile.path),
        name: "UTF16.txt",
        parent: canonicalTemporaryDirectoryPath,
        kind: .file,
        byteSize: Int64(utf16ContentData.count),
        modifiedAt: Date()
    )
    expect(
        SearchEngine.search(query: "utf16content:wide", in: [utf16ContentEntry]).first?.path == utf16ContentEntry.path,
        "utf16content: should search UTF-16 little-endian text"
    )
    expect(
        SearchEngine.search(query: "content:wide", in: [utf16ContentEntry]).first?.path == utf16ContentEntry.path,
        "content: should fall back to UTF-16 little-endian text"
    )
    expect(
        SearchEngine.search(query: "utf8content:wide", in: [utf16ContentEntry]).isEmpty,
        "utf8content: should not decode UTF-16-only text as UTF-8"
    )

    let utf16BEContentEntry = FileEntry(
        path: canonicalPath(utf16BEContentFile.path),
        name: "UTF16BE.txt",
        parent: canonicalTemporaryDirectoryPath,
        kind: .file,
        byteSize: Int64(utf16BEContentData.count),
        modifiedAt: Date()
    )
    expect(
        SearchEngine.search(query: "utf16becontent:big", in: [utf16BEContentEntry]).first?.path == utf16BEContentEntry.path,
        "utf16becontent: should search UTF-16 big-endian text"
    )
    expect(
        SearchEngine.search(query: "content:big", in: [utf16BEContentEntry]).first?.path == utf16BEContentEntry.path,
        "content: should fall back to UTF-16 big-endian text"
    )

    let ansiContentEntry = FileEntry(
        path: canonicalPath(ansiContentFile.path),
        name: "ANSI.txt",
        parent: canonicalTemporaryDirectoryPath,
        kind: .file,
        byteSize: Int64(ansiContentData.count),
        modifiedAt: Date()
    )
    expect(
        SearchEngine.search(query: "ansicontent:cafe", in: [ansiContentEntry]).first?.path == ansiContentEntry.path,
        "ansicontent: should search Windows-1252 text"
    )
    expect(
        SearchEngine.search(query: "content:cafe", in: [ansiContentEntry]).first?.path == ansiContentEntry.path,
        "content: should fall back to Windows-1252 text"
    )

    let tinyImageFile = temporaryDirectory.appending(path: "Tiny.png")
    let tinyImageBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAADklEQVR4nGP4z8DwHwQBEPgD/U6VwW8AAAAASUVORK5CYII="
    try Data(base64Encoded: tinyImageBase64)!.write(to: tinyImageFile)
    let tinyImageEntry = FileScanner.scanChangedPath(
        path: tinyImageFile.path,
        existingEntriesByPath: [:]
    ).first { $0.path == canonicalPath(tinyImageFile.path) }
    expect(
        tinyImageEntry != nil,
        "tiny PNG should be indexed for image metadata search"
    )
    let imageMetadataEntries = tinyImageEntry.map { [$0] } ?? []
    expect(
        SearchEngine.search(query: "width:2", in: imageMetadataEntries).first?.path == tinyImageEntry?.path,
        "width: should read image pixel width"
    )
    expect(
        SearchEngine.search(query: "width:>1", in: imageMetadataEntries).first?.path == tinyImageEntry?.path,
        "width: should support greater-than comparisons"
    )
    expect(
        SearchEngine.search(query: "width:!=1", in: imageMetadataEntries).first?.path == tinyImageEntry?.path,
        "width: should support not-equal comparisons"
    )
    expect(
        SearchEngine.search(query: "width:1;2", in: imageMetadataEntries).first?.path == tinyImageEntry?.path,
        "width: should support semicolon OR lists"
    )
    expect(
        SearchEngine.search(query: "height:1", in: imageMetadataEntries).first?.path == tinyImageEntry?.path,
        "height: should read image pixel height"
    )
    expect(
        SearchEngine.search(query: "height:<=1", in: imageMetadataEntries).first?.path == tinyImageEntry?.path,
        "height: should support less-than-or-equal comparisons"
    )
    expect(
        SearchEngine.search(query: "bit-depth:>0", in: imageMetadataEntries).first?.path == tinyImageEntry?.path,
        "bit-depth: should read image bit depth"
    )
    expect(
        SearchEngine.search(query: "dimensions:2x1", in: imageMetadataEntries).first?.path == tinyImageEntry?.path,
        "dimensions: should match exact image dimensions"
    )
    expect(
        SearchEngine.search(query: "dimensions:1x1..3x2", in: imageMetadataEntries).first?.path == tinyImageEntry?.path,
        "dimensions: should match image dimension ranges"
    )
    expect(
        SearchEngine.search(query: "orientation:landscape", in: imageMetadataEntries).first?.path == tinyImageEntry?.path,
        "orientation: should match landscape images"
    )
    expect(
        SearchEngine.search(query: "orientation:portrait;landscape", in: imageMetadataEntries).first?.path == tinyImageEntry?.path,
        "orientation: should support semicolon OR lists"
    )
    expect(
        SearchEngine.search(query: "orientation:portrait", in: imageMetadataEntries).isEmpty,
        "orientation: should reject non-matching image orientations"
    )
    expect(
        SearchEngine.search(query: "aspect-ratio:16:8", in: imageMetadataEntries).first?.path == tinyImageEntry?.path,
        "aspect-ratio: should match exact fractional ratios"
    )
    expect(
        SearchEngine.search(query: "aspect-ratio:>1", in: imageMetadataEntries).first?.path == tinyImageEntry?.path,
        "aspect-ratio: should support numerical comparisons"
    )
    expect(
        SearchEngine.search(query: "aspect-ratio:!=1", in: imageMetadataEntries).first?.path == tinyImageEntry?.path,
        "aspect-ratio: should support not-equal comparisons"
    )
    expect(
        SearchEngine.search(query: "aspect-ratio:16:8..16:10", in: imageMetadataEntries).first?.path == tinyImageEntry?.path,
        "aspect-ratio: should support fractional ranges"
    )
    expect(
        SearchEngine.search(query: "aspectratio:landscape", in: imageMetadataEntries).first?.path == tinyImageEntry?.path,
        "aspect-ratio: should support dashless names and orientation values"
    )

    let excludedDirectory = temporaryDirectory.appending(path: "Excluded", directoryHint: .isDirectory)
    let keptDirectory = temporaryDirectory.appending(path: "Kept", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: excludedDirectory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: keptDirectory, withIntermediateDirectories: true)

    let excludedByPathFile = excludedDirectory.appending(path: "Visible.md")
    let excludedByPatternFile = keptDirectory.appending(path: "Scratch.tmp")
    let excludedByExtensionFile = keptDirectory.appending(path: "Photo.JPG")
    let excludedHiddenFile = keptDirectory.appending(path: ".Hidden.md")
    let includedFile = keptDirectory.appending(path: "Notes.md")
    try Data("path".utf8).write(to: excludedByPathFile)
    try Data("pattern".utf8).write(to: excludedByPatternFile)
    try Data("extension".utf8).write(to: excludedByExtensionFile)
    try Data("hidden".utf8).write(to: excludedHiddenFile)
    try Data("included".utf8).write(to: includedFile)

    let exclusionRules = IndexExclusionRules(
        includeHiddenFiles: false,
        excludedPathPrefixes: [excludedDirectory.path],
        excludedNamePatterns: ["*.tmp"],
        excludedExtensions: ["JPG"]
    )
    let exclusionScan = FileScanner.scan(
        configuration: ScanConfiguration(rootURL: temporaryDirectory, exclusionRules: exclusionRules)
    )
    let exclusionScanPaths = exclusionScan.map(\.path)
    func exclusionScanContains(_ suffix: String) -> Bool {
        exclusionScanPaths.contains { $0.hasSuffix(suffix) }
    }
    expect(
        exclusionScanContains("/Kept/Notes.md"),
        "scanner should keep entries that do not match profile exclusion rules"
    )
    expect(
        !exclusionScanContains("/Excluded/Visible.md"),
        "scanner should exclude profile path prefixes before entries reach the index"
    )
    expect(
        !exclusionScanContains("/Kept/Scratch.tmp"),
        "scanner should exclude profile name wildcard patterns before entries reach the index"
    )
    expect(
        !exclusionScanContains("/Kept/Photo.JPG"),
        "scanner should exclude profile extensions before entries reach the index"
    )
    expect(
        !exclusionScanContains("/Kept/.Hidden.md"),
        "scanner should exclude hidden files when the active profile disables them"
    )

    let noisyDirectoryNames = [
        ".git",
        ".build",
        ".venv",
        ".mypy_cache",
        ".next",
        ".platformio",
        ".pio",
        ".npm",
        ".pnpm-store",
        "node_modules",
        "Pods",
        "venv"
    ]
    for noisyDirectoryName in noisyDirectoryNames {
        let noisyDirectory = temporaryDirectory.appending(path: noisyDirectoryName, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: noisyDirectory, withIntermediateDirectories: true)
        try Data("noise".utf8).write(to: noisyDirectory.appending(path: "Generated.txt"))
    }
    let defaultNoiseScan = FileScanner.scan(
        configuration: ScanConfiguration(rootURL: temporaryDirectory)
    )
    let defaultNoisePaths = defaultNoiseScan.map(\.path)
    expect(
        noisyDirectoryNames.allSatisfy { directoryName in
            !defaultNoisePaths.contains { $0.contains("/\(directoryName)/") || $0.hasSuffix("/\(directoryName)") }
        },
        "scanner should skip default developer and dependency noise directories"
    )

    let excludedChangedEntries = FileScanner.scanChangedPath(
        path: excludedByExtensionFile.path,
        existingEntriesByPath: [:],
        exclusionRules: exclusionRules
    )
    expect(
        excludedChangedEntries.isEmpty,
        "scanChangedPath should apply the same profile exclusion rules as full scans"
    )

    let noisyChangedEntries = FileScanner.scanChangedPath(
        path: temporaryDirectory.appending(path: ".venv", directoryHint: .isDirectory).path,
        existingEntriesByPath: [:]
    )
    expect(
        noisyChangedEntries.isEmpty,
        "scanChangedPath should skip default developer noise directories"
    )
    let noisyChildChangedEntries = FileScanner.scanChangedPath(
        path: temporaryDirectory
            .appending(path: "node_modules", directoryHint: .isDirectory)
            .appending(path: "Generated.txt")
            .path,
        existingEntriesByPath: [:]
    )
    expect(
        noisyChildChangedEntries.isEmpty,
        "scanChangedPath should skip changes below default developer noise directories"
    )
    expect(
        FileScanner.isPathInSkippedDirectory(
            temporaryDirectory
                .appending(path: ".git", directoryHint: .isDirectory)
                .appending(path: "objects", directoryHint: .isDirectory)
                .appending(path: "pack.tmp")
                .path,
            rootPath: temporaryDirectory.path
        ),
        "scanner should identify changes inside skipped directories for file-system monitoring"
    )
    expect(
        FileScanner.isPathInSkippedDirectory(
            temporaryDirectory
                .appending(path: "Sources", directoryHint: .isDirectory)
                .appending(path: "App.swift")
                .path,
            rootPath: temporaryDirectory.path
        ) == false,
        "scanner should keep ordinary changed files visible to file-system monitoring"
    )
    expect(
        FileScanner.isPathInSkippedDirectory("/.git/objects/pack.tmp", rootPath: "/"),
        "scanner should identify skipped directory changes when the indexed root is the filesystem root"
    )
    expect(
        FileScanner.isPathInSkippedDirectory("/Users/me/App.swift", rootPath: "/") == false,
        "scanner should keep ordinary root-level paths visible when the indexed root is the filesystem root"
    )

    let identityFile = temporaryDirectory.appending(path: "Identity.txt")
    let renamedIdentityFile = temporaryDirectory.appending(path: "Identity Renamed.txt")
    try Data("identity".utf8).write(to: identityFile)
    let originalIdentityEntry = FileScanner.scanChangedPath(
        path: identityFile.path,
        existingEntriesByPath: [:]
    ).first
    expect(
        originalIdentityEntry?.identityKey != nil,
        "scanner should capture filesystem identity metadata"
    )

    let runStampedIdentityEntry = originalIdentityEntry?.recordingRun(at: Date(timeIntervalSince1970: 6_000))
    try FileManager.default.moveItem(at: identityFile, to: renamedIdentityFile)
    let renamedIdentityEntry = FileScanner.scanChangedPath(
        path: renamedIdentityFile.path,
        existingEntriesByPath: runStampedIdentityEntry.map { [$0.path: $0] } ?? [:]
    ).first
    expect(
        renamedIdentityEntry?.identityKey == originalIdentityEntry?.identityKey,
        "filesystem identity should remain stable across renames"
    )
    let restoredIdentityEntry = renamedIdentityEntry.flatMap { entry in
        runStampedIdentityEntry.map { entry.preservingRunState(from: $0) }
    }
    expect(
        restoredIdentityEntry?.runCountValue == 1 &&
            restoredIdentityEntry?.lastRunAt == Date(timeIntervalSince1970: 6_000),
        "identity-matched entries should preserve run state across renames"
    )

    let databaseURL = temporaryDirectory.appending(path: "MacThing.db")
    let initialSnapshot = IndexSnapshot(rootPath: temporaryDirectory.path, entries: [photo, document])
    try IndexStorage.save(initialSnapshot, to: databaseURL)

    let fileListSourceURL = temporaryDirectory.appending(path: "FileLists.json")
    let fileListSource = FileListSource(
        name: "Offline Media",
        originalPath: "/Volumes/Archive/media.efu",
        isEnabled: false,
        entries: [folder, photo]
    )
    try FileListSourceStorage.save([fileListSource], to: fileListSourceURL)
    let loadedFileListSources = try FileListSourceStorage.load(from: fileListSourceURL)
    expect(
        loadedFileListSources.count == 1 &&
            loadedFileListSources[0].displayName == "Offline Media" &&
            loadedFileListSources[0].isEnabled == false &&
            loadedFileListSources[0].entries.map(\.path) == [folder.path, photo.path],
        "file-list sources should persist independently with enabled state and entries"
    )
    expect(
        loadedFileListSources[0].entriesWithSourceMetadata.allSatisfy {
            $0.fileListName == "Offline Media" &&
                $0.fileListPath == "/Volumes/Archive/media.efu"
        },
        "file-list sources should stamp entries with source metadata for filelistfilename: searches"
    )

    var loadedSnapshot = try IndexStorage.load(from: databaseURL)
    expect(
        loadedSnapshot.entries.map(\.path) == [document.path, photo.path].sorted(),
        "SQLite index storage should persist and load full snapshots"
    )
    let persistedEntryCount = try IndexStorage.entryCount(from: databaseURL)
    expect(
        persistedEntryCount == 2,
        "SQLite index storage should expose persisted entry counts without loading entries"
    )
    let persistedNoiseEntry = FileEntry(
        path: "/Users/me/Project/.venv/lib/site.py",
        name: "site.py",
        parent: "/Users/me/Project/.venv/lib",
        kind: .file,
        byteSize: 42,
        modifiedAt: Date(timeIntervalSince1970: 2_700)
    )
    try IndexStorage.upsert(entries: [persistedNoiseEntry], rootPath: temporaryDirectory.path, to: databaseURL)
    let removedSkippedEntries = try IndexStorage.deleteEntries(
        inSkippedDirectoryNames: FileScanner.defaultSkippedDirectoryNames,
        from: databaseURL
    )
    loadedSnapshot = try IndexStorage.load(from: databaseURL)
    expect(
        removedSkippedEntries == 1 &&
            loadedSnapshot.entries.contains { $0.path == persistedNoiseEntry.path } == false,
        "SQLite index storage should prune entries below default skipped directories"
    )

    try IndexStorage.upsert(entries: [hiddenEntry], rootPath: temporaryDirectory.path, to: databaseURL)
    loadedSnapshot = try IndexStorage.load(from: databaseURL)
    expect(
        loadedSnapshot.entries.first { $0.path == hiddenEntry.path }?.attributes.contains(.hidden) == true,
        "SQLite index storage should persist file attributes"
    )

    try IndexStorage.upsert(entries: [mediaTaggedEntry], rootPath: temporaryDirectory.path, to: databaseURL)
    loadedSnapshot = try IndexStorage.load(from: databaseURL)
    let loadedMediaEntry = loadedSnapshot.entries.first { $0.path == mediaTaggedEntry.path }
    expect(
        loadedMediaEntry?.mediaTitle == mediaTaggedEntry.mediaTitle &&
            loadedMediaEntry?.mediaArtist == mediaTaggedEntry.mediaArtist &&
            loadedMediaEntry?.mediaAlbum == mediaTaggedEntry.mediaAlbum &&
            loadedMediaEntry?.mediaComment == mediaTaggedEntry.mediaComment &&
            loadedMediaEntry?.mediaGenre == mediaTaggedEntry.mediaGenre &&
            loadedMediaEntry?.mediaTrack == mediaTaggedEntry.mediaTrack &&
            loadedMediaEntry?.mediaYear == mediaTaggedEntry.mediaYear,
        "SQLite index storage should persist media tag metadata"
    )

    let sqliteFileListEntry = FileEntry(
        path: "/Volumes/Archive/Catalog Movie.mkv",
        name: "Catalog Movie.mkv",
        parent: "/Volumes/Archive",
        kind: .file,
        byteSize: 100,
        modifiedAt: Date(timeIntervalSince1970: 3_050)
    ).markingFileListSource(
        name: "Offline Media.efu",
        path: "/Users/me/File Lists/Offline Media.efu"
    )
    let archiveFileListEntry = FileEntry(
        path: "/Volumes/Archive/Old Catalog Movie.mkv",
        name: "Old Catalog Movie.mkv",
        parent: "/Volumes/Archive",
        kind: .file,
        byteSize: 101,
        modifiedAt: Date(timeIntervalSince1970: 3_060)
    ).markingFileListSource(
        name: "Archive.efu",
        path: "/Users/me/File Lists/Archive.efu"
    )

    try IndexStorage.upsert(entries: [sqliteFileListEntry, archiveFileListEntry], rootPath: temporaryDirectory.path, to: databaseURL)
    loadedSnapshot = try IndexStorage.load(from: databaseURL)
    let loadedFileListEntry = loadedSnapshot.entries.first { $0.path == sqliteFileListEntry.path }
    expect(
        loadedFileListEntry?.fileListName == sqliteFileListEntry.fileListName &&
            loadedFileListEntry?.fileListPath == sqliteFileListEntry.fileListPath,
        "SQLite index storage should persist file-list source metadata"
    )

    if let restoredIdentityEntry {
        try IndexStorage.upsert(entries: [restoredIdentityEntry], rootPath: temporaryDirectory.path, to: databaseURL)
        loadedSnapshot = try IndexStorage.load(from: databaseURL)
        let loadedIdentityEntry = loadedSnapshot.entries.first { $0.path == restoredIdentityEntry.path }
        expect(
            loadedIdentityEntry?.identityKey == restoredIdentityEntry.identityKey &&
                loadedIdentityEntry?.runCountValue == restoredIdentityEntry.runCountValue,
            "SQLite index storage should persist filesystem identity metadata"
        )

        let identityRows = ResultExporter.rows(entries: [restoredIdentityEntry], columns: [.fileID, .volumeID])
        expect(
            identityRows.first?["fileID"]?.isEmpty == false &&
                identityRows.first?["volumeID"]?.isEmpty == false,
            "export rows should include filesystem identity columns"
        )
    }

    try IndexStorage.upsert(entries: [folder, symlinkEntry], rootPath: temporaryDirectory.path, to: databaseURL)
    loadedSnapshot = try IndexStorage.load(from: databaseURL)
    expect(
        loadedSnapshot.entries.contains { $0.path == folder.path },
        "SQLite index storage should upsert changed entries"
    )

    let parentOnlyCandidate = FileEntry(
        path: "/Users/me/ParentOnly/Other.txt",
        name: "Other.txt",
        parent: "/Users/me/ParentOnly",
        kind: .file,
        byteSize: 512,
        modifiedAt: Date(timeIntervalSince1970: 2_700),
        indexedAt: Date(timeIntervalSince1970: 2_700)
    )
    try IndexStorage.upsert(entries: [parentOnlyCandidate], rootPath: temporaryDirectory.path, to: databaseURL)
    let parentOnlyCandidates = try IndexStorage.candidateEntries(terms: ["ar"], limit: 20, from: databaseURL)
    expect(
        parentOnlyCandidates.contains { $0.path == parentOnlyCandidate.path },
        "SQLite LIKE fallback should preserve short parent/path substring candidates"
    )

    let namePrefixTarget = FileEntry(
        path: "/Users/me/NameFilters/NeedlePrefix.namefilter",
        name: "NeedlePrefix.namefilter",
        parent: "/Users/me/NameFilters",
        kind: .file,
        byteSize: 256,
        modifiedAt: Date(timeIntervalSince1970: 2_710),
        indexedAt: Date(timeIntervalSince1970: 2_710)
    )
    let namePrefixDecoy = FileEntry(
        path: "/Users/me/NameFilters/Other NeedlePrefix.namefilter",
        name: "Other NeedlePrefix.namefilter",
        parent: "/Users/me/NameFilters",
        kind: .file,
        byteSize: 257,
        modifiedAt: Date(timeIntervalSince1970: 2_711),
        indexedAt: Date(timeIntervalSince1970: 2_711)
    )
    let nameSuffixTarget = FileEntry(
        path: "/Users/me/NameFilters/Report.needlesuffix",
        name: "Report.needlesuffix",
        parent: "/Users/me/NameFilters",
        kind: .file,
        byteSize: 258,
        modifiedAt: Date(timeIntervalSince1970: 2_712),
        indexedAt: Date(timeIntervalSince1970: 2_712)
    )
    let nameSuffixDecoy = FileEntry(
        path: "/Users/me/NameFilters/Report.needlesuffix.old",
        name: "Report.needlesuffix.old",
        parent: "/Users/me/NameFilters",
        kind: .file,
        byteSize: 259,
        modifiedAt: Date(timeIntervalSince1970: 2_713),
        indexedAt: Date(timeIntervalSince1970: 2_713)
    )
    let exactNameTarget = FileEntry(
        path: "/Users/me/NameFilters/Exact Needle.namefilter",
        name: "Exact Needle.namefilter",
        parent: "/Users/me/NameFilters",
        kind: .file,
        byteSize: 260,
        modifiedAt: Date(timeIntervalSince1970: 2_714),
        indexedAt: Date(timeIntervalSince1970: 2_714)
    )
    let exactNameDecoy = FileEntry(
        path: "/Users/me/NameFilters/Exact Needle Copy.namefilter",
        name: "Exact Needle Copy.namefilter",
        parent: "/Users/me/NameFilters",
        kind: .file,
        byteSize: 261,
        modifiedAt: Date(timeIntervalSince1970: 2_715),
        indexedAt: Date(timeIntervalSince1970: 2_715)
    )
    let extensionOnlyNamePartDecoy = FileEntry(
        path: "/Users/me/NameFilters/Other.needleprefix",
        name: "Other.needleprefix",
        parent: "/Users/me/NameFilters",
        kind: .file,
        byteSize: 262,
        modifiedAt: Date(timeIntervalSince1970: 2_716),
        indexedAt: Date(timeIntervalSince1970: 2_716)
    )
    let pathPartTarget = FileEntry(
        path: "/Users/me/PathNeedle/Folder/PathPart Target.namefilter",
        name: "PathPart Target.namefilter",
        parent: "/Users/me/PathNeedle/Folder",
        kind: .file,
        byteSize: 263,
        modifiedAt: Date(timeIntervalSince1970: 2_717),
        indexedAt: Date(timeIntervalSince1970: 2_717)
    )
    let pathPartNameDecoy = FileEntry(
        path: "/Users/me/NameFilters/PathNeedle Name Only.namefilter",
        name: "PathNeedle Name Only.namefilter",
        parent: "/Users/me/NameFilters",
        kind: .file,
        byteSize: 264,
        modifiedAt: Date(timeIntervalSince1970: 2_718),
        indexedAt: Date(timeIntervalSince1970: 2_718)
    )
    try IndexStorage.upsert(
        entries: [
            namePrefixTarget,
            namePrefixDecoy,
            nameSuffixTarget,
            nameSuffixDecoy,
            exactNameTarget,
            exactNameDecoy,
            extensionOnlyNamePartDecoy,
            pathPartTarget,
            pathPartNameDecoy
        ],
        rootPath: temporaryDirectory.path,
        to: databaseURL
    )

    let namePrefixCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "start-with:NeedlePrefix", options: exactParentChildOptions)
        ),
        limit: 20,
        from: databaseURL
    )
    expect(
        namePrefixCandidates.map(\.path) == [namePrefixTarget.path],
        "SQLite candidate search should apply exact name-prefix filters"
    )

    let nameContainsCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "name:NeedlePrefix", options: exactParentChildOptions)
        ),
        limit: 20,
        from: databaseURL
    )
    expect(
        Set(nameContainsCandidates.map(\.path)) == Set([namePrefixTarget.path, namePrefixDecoy.path]),
        "SQLite candidate search should apply exact name-contains filters"
    )

    let stemContainsCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "stem:NeedlePrefix", options: exactParentChildOptions)
        ),
        limit: 20,
        from: databaseURL
    )
    expect(
        Set(stemContainsCandidates.map(\.path)) == Set([namePrefixTarget.path, namePrefixDecoy.path]),
        "SQLite candidate search should apply exact stem/name-part filters"
    )

    let pathPartContainsCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "path-part:/Users/me/PathNeedle", options: exactParentChildOptions)
        ),
        limit: 20,
        from: databaseURL
    )
    expect(
        pathPartContainsCandidates.map(\.path) == [pathPartTarget.path],
        "SQLite candidate search should apply exact path-part filters"
    )

    let nameSuffixCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "end-with:.needlesuffix", options: exactParentChildOptions)
        ),
        limit: 20,
        from: databaseURL
    )
    expect(
        nameSuffixCandidates.map(\.path) == [nameSuffixTarget.path],
        "SQLite candidate search should apply exact name-suffix filters"
    )

    let exactNameCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "exact:\"Exact Needle.namefilter\"", options: exactParentChildOptions)
        ),
        limit: 20,
        from: databaseURL
    )
    expect(
        exactNameCandidates.map(\.path) == [exactNameTarget.path],
        "SQLite candidate search should apply exact whole-filename filters"
    )

    let candidates = try IndexStorage.candidateEntries(terms: ["Launch"], limit: 20, from: databaseURL)
    expect(
        candidates.contains { $0.path == document.path } &&
            candidates.contains { $0.path == folder.path },
        "SQLite index storage should return candidates for simple terms"
    )

    let substringCandidates = try IndexStorage.candidateEntries(terms: ["unch"], limit: 20, from: databaseURL)
    expect(
        substringCandidates.contains { $0.path == document.path } &&
            substringCandidates.contains { $0.path == folder.path },
        "SQLite index storage should preserve substring candidates when FTS cannot match a middle fragment"
    )

    let jpgHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch ext:jpg"))
    let jpgCandidates = try IndexStorage.candidateEntries(hint: jpgHint, limit: 20, from: databaseURL)
    expect(
        jpgCandidates.map(\.path) == [photo.path],
        "SQLite candidate search should apply extension filters"
    )

    let extensionListCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "launch ext:jpg;jpeg")),
        limit: 20,
        from: databaseURL
    )
    expect(
        extensionListCandidates.map(\.path) == [photo.path],
        "SQLite candidate search should apply semicolon extension-list filters"
    )

    let wildcardJPGHint = SearchEngine.candidateHint(for: SearchRequest(query: "*.jpg"))
    let wildcardJPGCandidates = try IndexStorage.candidateEntries(hint: wildcardJPGHint, limit: 20, from: databaseURL)
    expect(
        wildcardJPGHint.canUseDatabaseCandidates &&
            wildcardJPGCandidates.map(\.path) == [photo.path],
        "SQLite candidate search should narrow literal-extension wildcard queries"
    )

    let noExtensionCandidates = try IndexStorage.candidateEntries(hint: noExtensionHint, limit: 20, from: databaseURL)
    expect(
        Set(noExtensionCandidates.map(\.path)) == Set([hiddenEntry.path, symlinkEntry.path]),
        "SQLite candidate search should apply empty extension filters without requiring terms"
    )

    let documentHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch type:document"))
    let documentCandidates = try IndexStorage.candidateEntries(hint: documentHint, limit: 20, from: databaseURL)
    expect(
        documentCandidates.map(\.path) == [document.path],
        "SQLite candidate search should apply type/category filters"
    )

    let categoryListCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "launch type:image;document")),
        limit: 20,
        from: databaseURL
    )
    expect(
        Set(categoryListCandidates.map(\.path)) == Set([photo.path, document.path]),
        "SQLite candidate search should apply semicolon category-list filters"
    )

    try IndexStorage.upsert(
        entries: [archiveEntry, executableScriptEntry, packageEntry],
        rootPath: temporaryDirectory.path,
        to: databaseURL
    )
    let compressedCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "backup zip:")),
        limit: 20,
        from: databaseURL
    )
    expect(
        compressedCandidates.map(\.path) == [archiveEntry.path],
        "SQLite candidate search should apply compressed archive filters"
    )

    let executableCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "deploy exe:")),
        limit: 20,
        from: databaseURL
    )
    expect(
        executableCandidates.map(\.path) == [executableScriptEntry.path],
        "SQLite candidate search should apply executable filters"
    )

    let appExecutableCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "macthing exe:")),
        limit: 20,
        from: databaseURL
    )
    expect(
        appExecutableCandidates.map(\.path) == [packageEntry.path],
        "SQLite candidate search should treat app packages as executable filters"
    )

    let parentLaunchHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch parent:/Users/me/Documents"))
    let parentLaunchCandidates = try IndexStorage.candidateEntries(hint: parentLaunchHint, limit: 20, from: databaseURL)
    expect(
        Set(parentLaunchCandidates.map(\.path)) == Set([document.path, folder.path]),
        "SQLite candidate search should apply direct parent filters"
    )

    let parentPathLaunchHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch parent-path:/Users/me/Documents"))
    let parentPathLaunchCandidates = try IndexStorage.candidateEntries(hint: parentPathLaunchHint, limit: 20, from: databaseURL)
    expect(
        Set(parentPathLaunchCandidates.map(\.path)) == Set([document.path, folder.path]),
        "SQLite candidate search should apply parent-path text filters"
    )

    let partialParentPathLaunchHint = SearchEngine.candidateHint(
        for: SearchRequest(query: "launch parent-path:/Users/me/Doc")
    )
    let partialParentPathLaunchCandidates = try IndexStorage.candidateEntries(
        hint: partialParentPathLaunchHint,
        limit: 20,
        from: databaseURL
    )
    expect(
        Set(partialParentPathLaunchCandidates.map(\.path)) == Set([document.path, folder.path]),
        "SQLite candidate search should preserve partial parent-path matches"
    )

    let shellCandidateDatabaseURL = temporaryDirectory.appending(path: "ShellCandidates.db")
    try IndexStorage.save(
        IndexSnapshot(
            rootPath: selfTestHomePath,
            entries: [shellDesktopFolder, shellDesktopFile, shellNestedDesktopFile, shellDocumentFile]
        ),
        to: shellCandidateDatabaseURL
    )
    let shellDesktopCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "shell:desktop")),
        limit: 20,
        from: shellCandidateDatabaseURL
    )
    expect(
        Set(shellDesktopCandidates.map(\.path)) ==
            Set([shellDesktopFolder.path, shellDesktopFile.path, shellNestedDesktopFile.path]),
        "SQLite candidate search should use known shell folder paths"
    )

    let shellDesktopLaunchCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "launch shell:desktop")),
        limit: 20,
        from: shellCandidateDatabaseURL
    )
    expect(
        Set(shellDesktopLaunchCandidates.map(\.path)) == Set([shellDesktopFile.path, shellNestedDesktopFile.path]),
        "SQLite candidate search should combine shell folder paths with text terms"
    )

    let parentMetadataCandidateDatabaseURL = temporaryDirectory.appending(path: "ParentMetadataCandidates.db")
    try IndexStorage.save(
        IndexSnapshot(
            rootPath: "/Users/me",
            entries: [metadataParentFolder, metadataParentChild, document]
        ),
        to: parentMetadataCandidateDatabaseURL
    )

    let parentCreatedDateCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "parent-dc:2024-02-03")),
        limit: 20,
        from: parentMetadataCandidateDatabaseURL
    )
    expect(
        parentCreatedDateCandidates.map(\.path) == [metadataParentChild.path],
        "SQLite candidate search should apply parent created-date filters"
    )

    let parentModifiedDateCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "parent-dm:2024-03-04")),
        limit: 20,
        from: parentMetadataCandidateDatabaseURL
    )
    expect(
        parentModifiedDateCandidates.map(\.path) == [metadataParentChild.path],
        "SQLite candidate search should apply parent modified-date filters"
    )

    let parentSizeCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "parent-size:4kb")),
        limit: 20,
        from: parentMetadataCandidateDatabaseURL
    )
    expect(
        parentSizeCandidates.map(\.path) == [metadataParentChild.path],
        "SQLite candidate search should apply parent-size filters"
    )

    let parentSizeRangeCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "parent-size:3kb..5kb")),
        limit: 20,
        from: parentMetadataCandidateDatabaseURL
    )
    expect(
        parentSizeRangeCandidates.map(\.path) == [metadataParentChild.path],
        "SQLite parent-size range filters should apply comparisons to the same indexed parent"
    )

    let identityCandidateDatabaseURL = temporaryDirectory.appending(path: "IdentityCandidates.db")
    try IndexStorage.save(
        IndexSnapshot(rootPath: temporaryDirectory.path, entries: [identitySearchEntry, otherIdentitySearchEntry, document]),
        to: identityCandidateDatabaseURL
    )
    let frnCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "frn:12345")),
        limit: 20,
        from: identityCandidateDatabaseURL
    )
    expect(
        frnCandidates.map(\.path) == [identitySearchEntry.path],
        "SQLite candidate search should apply file reference number filters"
    )

    let qualifiedFRNCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "frn:678:12345")),
        limit: 20,
        from: identityCandidateDatabaseURL
    )
    expect(
        qualifiedFRNCandidates.map(\.path) == [identitySearchEntry.path],
        "SQLite candidate search should apply volume-qualified file reference filters"
    )

    let identityPresenceCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "frn:")),
        limit: 20,
        from: identityCandidateDatabaseURL
    )
    expect(
        Set(identityPresenceCandidates.map(\.path)) == Set([identitySearchEntry.path, otherIdentitySearchEntry.path]),
        "SQLite candidate search should apply file identity presence filters"
    )

    let rootCandidateDatabaseURL = temporaryDirectory.appending(path: "RootCandidates.db")
    try IndexStorage.save(
        IndexSnapshot(rootPath: "/", entries: [rootLevelEntry, nameMatch]),
        to: rootCandidateDatabaseURL
    )
    let rootCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "root:")),
        limit: 20,
        from: rootCandidateDatabaseURL
    )
    expect(
        rootCandidates.map(\.path) == [rootLevelEntry.path],
        "SQLite candidate search should apply root-entry filters"
    )

    let depthCandidateDatabaseURL = temporaryDirectory.appending(path: "DepthCandidates.db")
    try IndexStorage.save(
        IndexSnapshot(rootPath: "/", entries: [rootLevelEntry, document, childInFolder, nestedGrandchild]),
        to: depthCandidateDatabaseURL
    )
    let depthCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "depth:4")),
        limit: 20,
        from: depthCandidateDatabaseURL
    )
    expect(
        depthCandidates.map(\.path) == [childInFolder.path],
        "SQLite candidate search should apply depth filters"
    )

    let parentCountCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "parent-count:>=4")),
        limit: 20,
        from: depthCandidateDatabaseURL
    )
    expect(
        Set(parentCountCandidates.map(\.path)) == Set([childInFolder.path, nestedGrandchild.path]),
        "SQLite candidate search should apply parent-count depth aliases"
    )

    let existsCandidateDatabaseURL = temporaryDirectory.appending(path: "ExistsCandidates.db")
    try IndexStorage.save(
        IndexSnapshot(rootPath: "/Users/me", entries: [sidecarAudio, sidecarImage, matchingFolderFile, matchingFolder]),
        to: existsCandidateDatabaseURL
    )
    let exactFileExistsCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "file-exists:Track.jpg")),
        limit: 20,
        from: existsCandidateDatabaseURL
    )
    expect(
        Set(exactFileExistsCandidates.map(\.path)) == Set([sidecarAudio.path, sidecarImage.path]),
        "SQLite candidate search should apply exact relative file-exists filters"
    )

    let combinedFileExistsCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "ext:mp3 file-exists:Track.jpg")),
        limit: 20,
        from: existsCandidateDatabaseURL
    )
    expect(
        combinedFileExistsCandidates.map(\.path) == [sidecarAudio.path],
        "SQLite candidate search should combine extension and file-exists filters"
    )

    let absoluteExistsCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "exists:/Users/me/Music/Track.jpg")),
        limit: 20,
        from: existsCandidateDatabaseURL
    )
    expect(
        Set(absoluteExistsCandidates.map(\.path)) ==
            Set([sidecarAudio.path, sidecarImage.path, matchingFolderFile.path, matchingFolder.path]),
        "SQLite candidate search should apply absolute exists filters"
    )

    let missingAbsoluteExistsCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "exists:/Users/me/Music/Missing.jpg")),
        limit: 20,
        from: existsCandidateDatabaseURL
    )
    expect(
        missingAbsoluteExistsCandidates.isEmpty,
        "SQLite candidate search should reject missing absolute exists filters"
    )

    let folderExistsCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "folder-exists:Archive")),
        limit: 20,
        from: existsCandidateDatabaseURL
    )
    expect(
        Set(folderExistsCandidates.map(\.path)) == Set([matchingFolderFile.path, matchingFolder.path]),
        "SQLite candidate search should apply exact folder-exists filters"
    )

    let pathListCandidateDatabaseURL = temporaryDirectory.appending(path: "PathListCandidates.db")
    try IndexStorage.save(
        IndexSnapshot(rootPath: "/", entries: [rootLevelEntry, pathMatch, deepPathMatch, photo]),
        to: pathListCandidateDatabaseURL
    )
    let exactPathListCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(
                query: "path-list:/Users/me/project/archive/readme.txt",
                options: exactParentChildOptions
            )
        ),
        limit: 20,
        from: pathListCandidateDatabaseURL
    )
    expect(
        exactPathListCandidates.map(\.path) == [pathMatch.path],
        "SQLite candidate search should apply exact path-list filters"
    )

    let exactFullPathListCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(
                query: "full-path-list:/Users/me/project/archive/deep/readme.txt",
                options: exactParentChildOptions
            )
        ),
        limit: 20,
        from: pathListCandidateDatabaseURL
    )
    expect(
        exactFullPathListCandidates.map(\.path) == [deepPathMatch.path],
        "SQLite candidate search should apply exact full-path-list filters"
    )

    let exactFileListNameCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "filelist:readme.txt", options: exactParentChildOptions)
        ),
        limit: 20,
        from: pathListCandidateDatabaseURL
    )
    expect(
        Set(exactFileListNameCandidates.map(\.path)) == Set([pathMatch.path, deepPathMatch.path]),
        "SQLite candidate search should apply exact filelist name filters"
    )

    let exactFileListPathCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(
                query: "filelist:/Users/me/project/archive/readme.txt",
                options: exactParentChildOptions
            )
        ),
        limit: 20,
        from: pathListCandidateDatabaseURL
    )
    expect(
        exactFileListPathCandidates.map(\.path) == [pathMatch.path],
        "SQLite candidate search should apply exact filelist path filters"
    )

    let siblingRelationCandidateDatabaseURL = temporaryDirectory.appending(path: "SiblingRelationCandidates.db")
    try IndexStorage.save(
        IndexSnapshot(
            rootPath: "/Users/me",
            entries: [document, folder, emptyFile, childInFolder, childFolderInFolder, nestedGrandchild, auntFolder]
        ),
        to: siblingRelationCandidateDatabaseURL
    )
    let parentSiblingPresenceCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "parent-sibling:")),
        limit: 20,
        from: siblingRelationCandidateDatabaseURL
    )
    expect(
        Set(parentSiblingPresenceCandidates.map(\.path)) ==
            Set([childInFolder.path, childFolderInFolder.path, nestedGrandchild.path]),
        "SQLite candidate search should apply parent-sibling presence filters"
    )

    let exactParentSiblingCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "parent-sibling:Empty", options: exactParentChildOptions)
        ),
        limit: 20,
        from: siblingRelationCandidateDatabaseURL
    )
    expect(
        Set(exactParentSiblingCandidates.map(\.path)) == Set([childInFolder.path, childFolderInFolder.path]),
        "SQLite candidate search should apply exact parent-sibling text filters"
    )

    let exactParentSiblingFileCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "parent-sibling-file:Empty", options: exactParentChildOptions)
        ),
        limit: 20,
        from: siblingRelationCandidateDatabaseURL
    )
    expect(
        Set(exactParentSiblingFileCandidates.map(\.path)) == Set([childInFolder.path, childFolderInFolder.path]),
        "SQLite candidate search should apply exact parent-sibling-file filters"
    )

    let exactParentSiblingFolderCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "parent-sibling-folder:Archive", options: exactParentChildOptions)
        ),
        limit: 20,
        from: siblingRelationCandidateDatabaseURL
    )
    expect(
        Set(exactParentSiblingFolderCandidates.map(\.path)) == Set([childInFolder.path, childFolderInFolder.path]),
        "SQLite candidate search should apply exact parent-sibling-folder filters"
    )

    let ancestorSiblingPresenceCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "ancestor-sibling:")),
        limit: 20,
        from: siblingRelationCandidateDatabaseURL
    )
    expect(
        Set(ancestorSiblingPresenceCandidates.map(\.path)) ==
            Set([childInFolder.path, childFolderInFolder.path, nestedGrandchild.path]),
        "SQLite candidate search should apply ancestor-sibling presence filters"
    )

    let exactAncestorSiblingCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "ancestor-sibling:Empty", options: exactParentChildOptions)
        ),
        limit: 20,
        from: siblingRelationCandidateDatabaseURL
    )
    expect(
        Set(exactAncestorSiblingCandidates.map(\.path)) ==
            Set([childInFolder.path, childFolderInFolder.path, nestedGrandchild.path]),
        "SQLite candidate search should apply exact ancestor-sibling text filters"
    )

    let exactAncestorSiblingFileCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "ancestor-sibling-file:Empty", options: exactParentChildOptions)
        ),
        limit: 20,
        from: siblingRelationCandidateDatabaseURL
    )
    expect(
        Set(exactAncestorSiblingFileCandidates.map(\.path)) ==
            Set([childInFolder.path, childFolderInFolder.path, nestedGrandchild.path]),
        "SQLite candidate search should apply exact ancestor-sibling-file filters"
    )

    let exactAncestorSiblingFolderCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "ancestor-sibling-folder:Archive", options: exactParentChildOptions)
        ),
        limit: 20,
        from: siblingRelationCandidateDatabaseURL
    )
    expect(
        Set(exactAncestorSiblingFolderCandidates.map(\.path)) ==
            Set([childInFolder.path, childFolderInFolder.path, nestedGrandchild.path]),
        "SQLite candidate search should apply exact ancestor-sibling-folder filters"
    )

    let lengthCandidateDatabaseURL = temporaryDirectory.appending(path: "LengthCandidates.db")
    try IndexStorage.save(
        IndexSnapshot(rootPath: "/Users/me", entries: [emojiNameEntry, utf8NameEntry, photo, document, folder]),
        to: lengthCandidateDatabaseURL
    )
    let characterCountCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "chars:\(emojiNameEntry.name.count)")),
        limit: 20,
        from: lengthCandidateDatabaseURL
    )
    expect(
        characterCountCandidates.map(\.path) == [emojiNameEntry.path],
        "SQLite candidate search should apply Swift character-count filters"
    )

    let nameLengthCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "len:\(emojiNameEntry.name.utf16.count)")),
        limit: 20,
        from: lengthCandidateDatabaseURL
    )
    expect(
        Set(nameLengthCandidates.map(\.path)) == Set([emojiNameEntry.path, folder.path]),
        "SQLite candidate search should apply UTF-16 name-length filters"
    )

    let nameUTF8LengthCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "utf8-len:\(utf8NameEntry.name.utf8.count)")),
        limit: 20,
        from: lengthCandidateDatabaseURL
    )
    expect(
        nameUTF8LengthCandidates.map(\.path) == [utf8NameEntry.path],
        "SQLite candidate search should apply UTF-8 name-length filters"
    )

    let pathLengthCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "path-len:\(photo.path.utf16.count)")),
        limit: 20,
        from: lengthCandidateDatabaseURL
    )
    expect(
        pathLengthCandidates.map(\.path) == [photo.path],
        "SQLite candidate search should apply UTF-16 path-length filters"
    )

    let extensionLengthCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "ext-len:3")),
        limit: 20,
        from: lengthCandidateDatabaseURL
    )
    expect(
        Set(extensionLengthCandidates.map(\.path)) == Set([photo.path, utf8NameEntry.path, emojiNameEntry.path]),
        "SQLite candidate search should apply extension-length filters"
    )

    let frequencyCandidateDatabaseURL = temporaryDirectory.appending(path: "FrequencyCandidates.db")
    try IndexStorage.save(
        IndexSnapshot(rootPath: "/Users/me", entries: [document, duplicateA, duplicateB, photo, folder]),
        to: frequencyCandidateDatabaseURL
    )
    let exactNameFrequencyCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "name-frequency:>1", options: exactParentChildOptions)
        ),
        limit: 20,
        from: frequencyCandidateDatabaseURL
    )
    expect(
        Set(exactNameFrequencyCandidates.map(\.path)) == Set([duplicateA.path, duplicateB.path]),
        "SQLite candidate search should apply exact name-frequency filters"
    )

    let exactExtensionFrequencyCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "extension-frequency:>1", options: exactParentChildOptions)
        ),
        limit: 20,
        from: frequencyCandidateDatabaseURL
    )
    expect(
        Set(exactExtensionFrequencyCandidates.map(\.path)) == Set([document.path, duplicateA.path, duplicateB.path]),
        "SQLite candidate search should apply exact extension-frequency filters"
    )

    let exactDuplicateNameCandidateDatabaseURL = temporaryDirectory.appending(path: "ExactDuplicateNameCandidates.db")
    try IndexStorage.save(
        IndexSnapshot(rootPath: "/Users/me", entries: [document, duplicateA, duplicateB]),
        to: exactDuplicateNameCandidateDatabaseURL
    )
    let exactDuplicateNameCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "dupe:", options: exactParentChildOptions)
        ),
        limit: 20,
        from: exactDuplicateNameCandidateDatabaseURL
    )
    expect(
        Set(exactDuplicateNameCandidates.map(\.path)) == Set([duplicateA.path, duplicateB.path]),
        "SQLite candidate search should apply exact duplicate-name filters"
    )

    let exactUniqueNameCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "dupe:0", options: exactParentChildOptions)
        ),
        limit: 20,
        from: exactDuplicateNameCandidateDatabaseURL
    )
    expect(
        exactUniqueNameCandidates.map(\.path) == [document.path],
        "SQLite candidate search should apply exact unique-name filters"
    )

    let exactNamePartCandidateDatabaseURL = temporaryDirectory.appending(path: "ExactNamePartCandidates.db")
    try IndexStorage.save(
        IndexSnapshot(rootPath: "/Users/me", entries: duplicateMetricEntries),
        to: exactNamePartCandidateDatabaseURL
    )
    let exactNamePartDupeCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "namepartdupe:", options: exactParentChildOptions)
        ),
        limit: 20,
        from: exactNamePartCandidateDatabaseURL
    )
    expect(
        Set(exactNamePartDupeCandidates.map(\.path)) == Set([sameNamePartText.path, sameNamePartMarkdown.path]),
        "SQLite candidate search should apply exact duplicate name-part filters"
    )

    let exactPathDupeCandidateDatabaseURL = temporaryDirectory.appending(path: "ExactPathDupeCandidates.db")
    try IndexStorage.save(
        IndexSnapshot(rootPath: "/Users/me", entries: [document, folder, emptyFile, childInFolder]),
        to: exactPathDupeCandidateDatabaseURL
    )
    let exactPathDupeCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "path-dupe:", options: exactParentChildOptions)
        ),
        limit: 20,
        from: exactPathDupeCandidateDatabaseURL
    )
    expect(
        Set(exactPathDupeCandidates.map(\.path)) == Set([document.path, folder.path, emptyFile.path]),
        "SQLite candidate search should apply exact duplicate path-part filters"
    )

    let exactUniquePathCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "path-dupe:0", options: exactParentChildOptions)
        ),
        limit: 20,
        from: exactPathDupeCandidateDatabaseURL
    )
    expect(
        exactUniquePathCandidates.map(\.path) == [childInFolder.path],
        "SQLite candidate search should apply exact unique path-part filters"
    )

    let childCountCandidateDatabaseURL = temporaryDirectory.appending(path: "ChildCountCandidates.db")
    try IndexStorage.save(
        IndexSnapshot(rootPath: "/Users/me", entries: [document, folder, childInFolder, childFolderInFolder, nestedGrandchild]),
        to: childCountCandidateDatabaseURL
    )
    let childPresenceCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "child:")),
        limit: 20,
        from: childCountCandidateDatabaseURL
    )
    expect(
        Set(childPresenceCandidates.map(\.path)) == Set([folder.path, childFolderInFolder.path]),
        "SQLite candidate search should apply child presence filters"
    )

    let exactChildCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "child:Child", options: exactParentChildOptions)
        ),
        limit: 20,
        from: childCountCandidateDatabaseURL
    )
    expect(
        exactChildCandidates.map(\.path) == [folder.path],
        "SQLite candidate search should apply exact child text filters"
    )

    let exactChildFileCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "child-file:Child", options: exactParentChildOptions)
        ),
        limit: 20,
        from: childCountCandidateDatabaseURL
    )
    expect(
        exactChildFileCandidates.map(\.path) == [folder.path],
        "SQLite candidate search should apply exact child-file filters"
    )

    let exactChildFolderCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "child-folder:Nested", options: exactParentChildOptions)
        ),
        limit: 20,
        from: childCountCandidateDatabaseURL
    )
    expect(
        exactChildFolderCandidates.map(\.path) == [folder.path],
        "SQLite candidate search should apply exact child-folder filters"
    )

    let childCountCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "childcount:>0")),
        limit: 20,
        from: childCountCandidateDatabaseURL
    )
    expect(
        Set(childCountCandidates.map(\.path)) == Set([folder.path, childFolderInFolder.path]),
        "SQLite candidate search should apply child-count filters"
    )

    let zeroChildCountCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "childcount:0")),
        limit: 20,
        from: childCountCandidateDatabaseURL
    )
    expect(
        zeroChildCountCandidates.isEmpty,
        "SQLite child-count filters should not treat non-containers as zero-child containers"
    )

    let childFileCountCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "childfilecount:1")),
        limit: 20,
        from: childCountCandidateDatabaseURL
    )
    expect(
        Set(childFileCountCandidates.map(\.path)) == Set([folder.path, childFolderInFolder.path]),
        "SQLite candidate search should apply child-file-count filters"
    )

    let childFolderCountCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "childfoldercount:1")),
        limit: 20,
        from: childCountCandidateDatabaseURL
    )
    expect(
        childFolderCountCandidates.map(\.path) == [folder.path],
        "SQLite candidate search should apply child-folder-count filters"
    )

    let descendantPresenceCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "descendant:")),
        limit: 20,
        from: childCountCandidateDatabaseURL
    )
    expect(
        Set(descendantPresenceCandidates.map(\.path)) == Set([folder.path, childFolderInFolder.path]),
        "SQLite candidate search should apply descendant presence filters"
    )

    let exactDescendantCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "descendant:Grandchild", options: exactParentChildOptions)
        ),
        limit: 20,
        from: childCountCandidateDatabaseURL
    )
    expect(
        Set(exactDescendantCandidates.map(\.path)) == Set([folder.path, childFolderInFolder.path]),
        "SQLite candidate search should apply exact descendant text filters"
    )

    let exactDescendantFileCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "descendant-file:Grandchild", options: exactParentChildOptions)
        ),
        limit: 20,
        from: childCountCandidateDatabaseURL
    )
    expect(
        Set(exactDescendantFileCandidates.map(\.path)) == Set([folder.path, childFolderInFolder.path]),
        "SQLite candidate search should apply exact descendant-file filters"
    )

    let exactDescendantFolderCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "descendant-folder:Nested", options: exactParentChildOptions)
        ),
        limit: 20,
        from: childCountCandidateDatabaseURL
    )
    expect(
        exactDescendantFolderCandidates.map(\.path) == [folder.path],
        "SQLite candidate search should apply exact descendant-folder filters"
    )

    let ancestorChildPresenceCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "ancestor-child:")),
        limit: 20,
        from: childCountCandidateDatabaseURL
    )
    expect(
        Set(ancestorChildPresenceCandidates.map(\.path)) ==
            Set([document.path, folder.path, childInFolder.path, childFolderInFolder.path, nestedGrandchild.path]),
        "SQLite candidate search should apply ancestor-child presence filters"
    )

    let exactAncestorChildCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "ancestor-child:Child", options: exactParentChildOptions)
        ),
        limit: 20,
        from: childCountCandidateDatabaseURL
    )
    expect(
        Set(exactAncestorChildCandidates.map(\.path)) ==
            Set([childInFolder.path, childFolderInFolder.path, nestedGrandchild.path]),
        "SQLite candidate search should apply exact ancestor-child text filters"
    )

    let exactAncestorChildFileCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "ancestor-child-file:Child", options: exactParentChildOptions)
        ),
        limit: 20,
        from: childCountCandidateDatabaseURL
    )
    expect(
        Set(exactAncestorChildFileCandidates.map(\.path)) ==
            Set([childInFolder.path, childFolderInFolder.path, nestedGrandchild.path]),
        "SQLite candidate search should apply exact ancestor-child-file filters"
    )

    let exactAncestorChildFolderCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "ancestor-child-folder:Nested", options: exactParentChildOptions)
        ),
        limit: 20,
        from: childCountCandidateDatabaseURL
    )
    expect(
        Set(exactAncestorChildFolderCandidates.map(\.path)) ==
            Set([childInFolder.path, childFolderInFolder.path, nestedGrandchild.path]),
        "SQLite candidate search should apply exact ancestor-child-folder filters"
    )

    let descendantCountCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "descendant-count:3")),
        limit: 20,
        from: childCountCandidateDatabaseURL
    )
    expect(
        descendantCountCandidates.map(\.path) == [folder.path],
        "SQLite candidate search should apply descendant-count filters"
    )

    let descendantFileCountCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "descendant-file-count:2")),
        limit: 20,
        from: childCountCandidateDatabaseURL
    )
    expect(
        descendantFileCountCandidates.map(\.path) == [folder.path],
        "SQLite candidate search should apply descendant-file-count filters"
    )

    let descendantFolderCountCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "descendant-folder-count:1")),
        limit: 20,
        from: childCountCandidateDatabaseURL
    )
    expect(
        descendantFolderCountCandidates.map(\.path) == [folder.path],
        "SQLite candidate search should apply descendant-folder-count filters"
    )

    let zeroDescendantCountCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "descendant-count:0")),
        limit: 20,
        from: childCountCandidateDatabaseURL
    )
    expect(
        zeroDescendantCountCandidates.isEmpty,
        "SQLite descendant-count filters should not treat non-containers as zero-descendant containers"
    )

    let totalChildSizeCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "total-child-size:12")),
        limit: 20,
        from: childCountCandidateDatabaseURL
    )
    expect(
        totalChildSizeCandidates.map(\.path) == [folder.path],
        "SQLite candidate search should apply total-child-size filters"
    )

    let nestedTotalChildSizeCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "total-child-size:1000")),
        limit: 20,
        from: childCountCandidateDatabaseURL
    )
    expect(
        nestedTotalChildSizeCandidates.map(\.path) == [childFolderInFolder.path],
        "SQLite total-child-size filters should sum direct file children only"
    )

    let zeroTotalChildSizeCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "total-child-size:0")),
        limit: 20,
        from: childCountCandidateDatabaseURL
    )
    expect(
        zeroTotalChildSizeCandidates.isEmpty,
        "SQLite total-child-size filters should not treat non-containers as zero-size containers"
    )

    let childSizeCandidateDatabaseURL = temporaryDirectory.appending(path: "ChildSizeCandidates.db")
    try IndexStorage.save(
        IndexSnapshot(rootPath: "/Users/me", entries: [document, folder, childMetadataFile, childMetadataFolder]),
        to: childSizeCandidateDatabaseURL
    )
    let childSizeCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "child-size:2048")),
        limit: 20,
        from: childSizeCandidateDatabaseURL
    )
    expect(
        childSizeCandidates.map(\.path) == [folder.path],
        "SQLite candidate search should apply child-size filters"
    )

    let childSizeRangeCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "child-size:2kb..3kb")),
        limit: 20,
        from: childSizeCandidateDatabaseURL
    )
    expect(
        childSizeRangeCandidates.map(\.path) == [folder.path],
        "SQLite child-size range filters should apply comparisons to the same direct child"
    )

    let childFileSizeCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "child-file-size:2048")),
        limit: 20,
        from: childSizeCandidateDatabaseURL
    )
    expect(
        childFileSizeCandidates.map(\.path) == [folder.path],
        "SQLite candidate search should apply child-file-size filters"
    )

    let childFolderSizeCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "child-folder-size:4096")),
        limit: 20,
        from: childSizeCandidateDatabaseURL
    )
    expect(
        childFolderSizeCandidates.map(\.path) == [folder.path],
        "SQLite candidate search should apply child-folder-size filters"
    )

    let childRunCountCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "child-run-count:7")),
        limit: 20,
        from: childSizeCandidateDatabaseURL
    )
    expect(
        childRunCountCandidates.map(\.path) == [folder.path],
        "SQLite candidate search should apply child-run-count filters"
    )

    let childRunCountRangeCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "child-run-count:6..8")),
        limit: 20,
        from: childSizeCandidateDatabaseURL
    )
    expect(
        childRunCountRangeCandidates.map(\.path) == [folder.path],
        "SQLite child-run-count range filters should apply comparisons to the same direct child"
    )

    let childFileRunCountCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "child-file-run-count:7")),
        limit: 20,
        from: childSizeCandidateDatabaseURL
    )
    expect(
        childFileRunCountCandidates.map(\.path) == [folder.path],
        "SQLite candidate search should apply child-file-run-count filters"
    )

    let childFolderRunCountCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "child-folder-run-count:3")),
        limit: 20,
        from: childSizeCandidateDatabaseURL
    )
    expect(
        childFolderRunCountCandidates.map(\.path) == [folder.path],
        "SQLite candidate search should apply child-folder-run-count filters"
    )

    let childModifiedDateCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "child-dm:2024-05-02")),
        limit: 20,
        from: childSizeCandidateDatabaseURL
    )
    expect(
        childModifiedDateCandidates.map(\.path) == [folder.path],
        "SQLite candidate search should apply child modified-date filters"
    )

    let childFileAccessedDateCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "child-file-date-accessed:2024-05-03")),
        limit: 20,
        from: childSizeCandidateDatabaseURL
    )
    expect(
        childFileAccessedDateCandidates.map(\.path) == [folder.path],
        "SQLite candidate search should apply child-file accessed-date filters"
    )

    let childFolderModifiedDateCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "child-folder-dm:2024-06-02")),
        limit: 20,
        from: childSizeCandidateDatabaseURL
    )
    expect(
        childFolderModifiedDateCandidates.map(\.path) == [folder.path],
        "SQLite candidate search should apply child-folder modified-date filters"
    )

    let childDateRunCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "child-date-run:2024-05-05")),
        limit: 20,
        from: childSizeCandidateDatabaseURL
    )
    expect(
        childDateRunCandidates.map(\.path) == [folder.path],
        "SQLite candidate search should apply child date-run filters"
    )

    let childFileListNameCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(
                query: "child-file-list:Metadata.bin;Missing.bin",
                options: exactChildFileListOptions
            )
        ),
        limit: 20,
        from: childSizeCandidateDatabaseURL
    )
    expect(
        childFileListNameCandidates.map(\.path) == [folder.path],
        "SQLite candidate search should apply exact child-file-list name filters"
    )

    let childFileListPathCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(
                query: "child-file-list:/Users/me/Documents/Launch/MetadataFolder",
                options: exactChildFileListOptions
            )
        ),
        limit: 20,
        from: childSizeCandidateDatabaseURL
    )
    expect(
        childFileListPathCandidates.map(\.path) == [folder.path],
        "SQLite candidate search should apply exact child-file-list path filters"
    )

    let childFileListPartialCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(
                query: "child-file-list:Metadata",
                options: exactChildFileListOptions
            )
        ),
        limit: 20,
        from: childSizeCandidateDatabaseURL
    )
    expect(
        childFileListPartialCandidates.isEmpty,
        "SQLite child-file-list filters should not perform partial child filename matching"
    )

    let childAttributeCandidateDatabaseURL = temporaryDirectory.appending(path: "ChildAttributeCandidates.db")
    try IndexStorage.save(
        IndexSnapshot(rootPath: "/Users/me", entries: [folder, childInFolder, hiddenChildInFolder, childFolderInFolder]),
        to: childAttributeCandidateDatabaseURL
    )
    let childAttributeCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "child-attr:h")),
        limit: 20,
        from: childAttributeCandidateDatabaseURL
    )
    expect(
        childAttributeCandidates.map(\.path) == [folder.path],
        "SQLite candidate search should apply child-attr filters"
    )

    let childFileAttributeCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "child-file-attr:h")),
        limit: 20,
        from: childAttributeCandidateDatabaseURL
    )
    expect(
        childFileAttributeCandidates.map(\.path) == [folder.path],
        "SQLite candidate search should apply child-file-attr filters"
    )

    let childFileExcludedAttributeCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "child-file-attr:!h")),
        limit: 20,
        from: childAttributeCandidateDatabaseURL
    )
    expect(
        childFileExcludedAttributeCandidates.map(\.path) == [folder.path],
        "SQLite candidate search should apply negative child-file-attr filters"
    )

    let childFolderAttributeCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "child-folder-attr:d")),
        limit: 20,
        from: childAttributeCandidateDatabaseURL
    )
    expect(
        childFolderAttributeCandidates.map(\.path) == [folder.path],
        "SQLite candidate search should apply child-folder-attr filters"
    )

    let ancestorAttributeCandidateDatabaseURL = temporaryDirectory.appending(path: "AncestorAttributeCandidates.db")
    try IndexStorage.save(
        IndexSnapshot(
            rootPath: "/Users/me",
            entries: [folder, childFolderInFolder, nestedGrandchild, hiddenAncestorFolder, childUnderHiddenAncestor]
        ),
        to: ancestorAttributeCandidateDatabaseURL
    )
    let ancestorDirectoryAttributeCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "ancestor-attr:d")),
        limit: 20,
        from: ancestorAttributeCandidateDatabaseURL
    )
    expect(
        Set(ancestorDirectoryAttributeCandidates.map(\.path)) ==
            Set([childFolderInFolder.path, nestedGrandchild.path, childUnderHiddenAncestor.path]),
        "SQLite candidate search should apply ancestor-attr filters through indexed parent chains"
    )

    let ancestorHiddenAttributeCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "ancestor-attribute:h")),
        limit: 20,
        from: ancestorAttributeCandidateDatabaseURL
    )
    expect(
        ancestorHiddenAttributeCandidates.map(\.path) == [childUnderHiddenAncestor.path],
        "SQLite candidate search should apply ancestor-attribute aliases"
    )

    let ancestorExcludedAttributeCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "ancestor-attr:!h")),
        limit: 20,
        from: ancestorAttributeCandidateDatabaseURL
    )
    expect(
        Set(ancestorExcludedAttributeCandidates.map(\.path)) == Set([childFolderInFolder.path, nestedGrandchild.path]),
        "SQLite candidate search should apply negative ancestor-attr filters"
    )

    let parentChildCandidateDatabaseURL = temporaryDirectory.appending(path: "ParentChildCandidates.db")
    try IndexStorage.save(
        IndexSnapshot(rootPath: "/Users/me", entries: [document, folder, emptyFile, childInFolder]),
        to: parentChildCandidateDatabaseURL
    )
    let parentChildPresenceCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "parent-child:")),
        limit: 20,
        from: parentChildCandidateDatabaseURL
    )
    expect(
        Set(parentChildPresenceCandidates.map(\.path)) ==
            Set([document.path, folder.path, emptyFile.path, childInFolder.path]),
        "SQLite candidate search should apply parent-child presence filters"
    )

    let exactParentChildCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "parent-child:Empty", options: exactParentChildOptions)
        ),
        limit: 20,
        from: parentChildCandidateDatabaseURL
    )
    expect(
        Set(exactParentChildCandidates.map(\.path)) == Set([document.path, folder.path, emptyFile.path]),
        "SQLite candidate search should apply exact parent-child text filters"
    )

    let exactParentChildSelfCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "parent-child:Child", options: exactParentChildOptions)
        ),
        limit: 20,
        from: parentChildCandidateDatabaseURL
    )
    expect(
        exactParentChildSelfCandidates.map(\.path) == [childInFolder.path],
        "SQLite parent-child filters should include the entry itself as one of its parent's children"
    )

    let exactParentChildFolderCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "parent-child-folder:Launch", options: exactParentChildOptions)
        ),
        limit: 20,
        from: parentChildCandidateDatabaseURL
    )
    expect(
        Set(exactParentChildFolderCandidates.map(\.path)) == Set([document.path, folder.path, emptyFile.path]),
        "SQLite candidate search should apply exact parent-child-folder filters"
    )

    let siblingCountCandidateDatabaseURL = temporaryDirectory.appending(path: "SiblingCountCandidates.db")
    try IndexStorage.save(
        IndexSnapshot(rootPath: "/Users/me", entries: [document, folder, emptyFile, childInFolder]),
        to: siblingCountCandidateDatabaseURL
    )
    let siblingPresenceCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "sibling:")),
        limit: 20,
        from: siblingCountCandidateDatabaseURL
    )
    expect(
        Set(siblingPresenceCandidates.map(\.path)) == Set([document.path, folder.path, emptyFile.path]),
        "SQLite candidate search should apply sibling presence filters"
    )

    let exactSiblingCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "sibling:Empty", options: exactParentChildOptions)
        ),
        limit: 20,
        from: siblingCountCandidateDatabaseURL
    )
    expect(
        Set(exactSiblingCandidates.map(\.path)) == Set([document.path, folder.path]),
        "SQLite candidate search should apply exact sibling text filters"
    )

    let exactSiblingFileCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "sibling-file:Empty", options: exactParentChildOptions)
        ),
        limit: 20,
        from: siblingCountCandidateDatabaseURL
    )
    expect(
        Set(exactSiblingFileCandidates.map(\.path)) == Set([document.path, folder.path]),
        "SQLite candidate search should apply exact sibling-file filters"
    )

    let exactSiblingFolderCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "sibling-folder:Launch", options: exactParentChildOptions)
        ),
        limit: 20,
        from: siblingCountCandidateDatabaseURL
    )
    expect(
        Set(exactSiblingFolderCandidates.map(\.path)) == Set([document.path, emptyFile.path]),
        "SQLite candidate search should apply exact sibling-folder filters"
    )

    let siblingCountCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "sibling-count:2")),
        limit: 20,
        from: siblingCountCandidateDatabaseURL
    )
    expect(
        Set(siblingCountCandidates.map(\.path)) == Set([document.path, folder.path, emptyFile.path]),
        "SQLite candidate search should apply sibling-count filters"
    )

    let siblingFileCountCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "sibling-file-count:2")),
        limit: 20,
        from: siblingCountCandidateDatabaseURL
    )
    expect(
        siblingFileCountCandidates.map(\.path) == [folder.path],
        "SQLite candidate search should apply sibling-file-count filters"
    )

    let siblingFolderCountCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "sibling-folder-count:1")),
        limit: 20,
        from: siblingCountCandidateDatabaseURL
    )
    expect(
        Set(siblingFolderCountCandidates.map(\.path)) == Set([document.path, emptyFile.path]),
        "SQLite candidate search should apply sibling-folder-count filters"
    )

    let broadPathFTSDecoys = (0..<25).map { index in
        FileEntry(
            path: "/Users/me/Projects/DocLateNoise\(index)/Needle Overflow \(index).txt",
            name: "Needle Overflow \(index).txt",
            parent: "/Users/me/Projects/DocLateNoise\(index)",
            kind: .file,
            byteSize: 100 + Int64(index),
            modifiedAt: Date(timeIntervalSince1970: 3_000 + TimeInterval(index)),
            indexedAt: Date(timeIntervalSince1970: 3_000 + TimeInterval(index))
        )
    }
    let lateSubstringTarget = FileEntry(
        path: "/Users/me/DocLateFolder/Needle Keeper.md",
        name: "Needle Keeper.md",
        parent: "/Users/me/DocLateFolder",
        kind: .file,
        byteSize: 1_024,
        modifiedAt: Date(timeIntervalSince1970: 4_000),
        indexedAt: Date(timeIntervalSince1970: 4_000)
    )
    try IndexStorage.upsert(entries: broadPathFTSDecoys, rootPath: temporaryDirectory.path, to: databaseURL)
    try IndexStorage.upsert(entries: [lateSubstringTarget], rootPath: temporaryDirectory.path, to: databaseURL)
    let lateSubstringHint = SearchEngine.candidateHint(
        for: SearchRequest(query: "needle parent-path:/Users/me/DocLate")
    )
    let lateSubstringCandidates = try IndexStorage.candidateEntries(
        hint: lateSubstringHint,
        limit: 20,
        from: databaseURL
    )
    expect(
        lateSubstringCandidates.contains { $0.path == lateSubstringTarget.path },
        "SQLite candidate search should continue to substring fallback when broad FTS fills the window"
    )

    let hiddenHint = SearchEngine.candidateHint(for: SearchRequest(query: "secret hidden:"))
    let hiddenCandidates = try IndexStorage.candidateEntries(hint: hiddenHint, limit: 20, from: databaseURL)
    expect(
        hiddenCandidates.map(\.path) == [hiddenEntry.path],
        "SQLite candidate search should apply required attribute filters"
    )

    let visibleLaunchHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch hidden:0"))
    let visibleLaunchCandidates = try IndexStorage.candidateEntries(hint: visibleLaunchHint, limit: 20, from: databaseURL)
    expect(
        visibleLaunchCandidates.contains { $0.path == photo.path } &&
            visibleLaunchCandidates.contains { $0.path == document.path } &&
            visibleLaunchCandidates.contains { $0.path == folder.path } &&
            visibleLaunchCandidates.contains { $0.path == hiddenEntry.path } == false,
        "SQLite candidate search should apply excluded attribute filters"
    )

    try IndexStorage.upsert(entries: [launchedTwice, launchedOnce], rootPath: temporaryDirectory.path, to: databaseURL)
    let launchedOftenHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch runcount:>1"))
    let launchedOftenCandidates = try IndexStorage.candidateEntries(hint: launchedOftenHint, limit: 20, from: databaseURL)
    expect(
        launchedOftenCandidates.map(\.path) == [launchedTwice.path],
        "SQLite candidate search should apply run-count filters"
    )

    let dateRunLaunchHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch dr:1970-01-01"))
    let dateRunLaunchCandidates = try IndexStorage.candidateEntries(hint: dateRunLaunchHint, limit: 20, from: databaseURL)
    expect(
        Set(dateRunLaunchCandidates.map(\.path)) == Set([launchedTwice.path, launchedOnce.path]),
        "SQLite candidate search should apply date-run filters"
    )

    let largeLaunchHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch size:>1mb"))
    let largeLaunchCandidates = try IndexStorage.candidateEntries(hint: largeLaunchHint, limit: 20, from: databaseURL)
    expect(
        largeLaunchCandidates.map(\.path) == [photo.path],
        "SQLite candidate search should apply size filters"
    )

    let largeConstantLaunchHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch size:large"))
    let largeConstantLaunchCandidates = try IndexStorage.candidateEntries(hint: largeConstantLaunchHint, limit: 20, from: databaseURL)
    expect(
        largeConstantLaunchCandidates.map(\.path) == [photo.path],
        "SQLite candidate search should apply size constant filters"
    )

    let rangeLaunchHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch size:1kb..3mb"))
    let rangeLaunchCandidates = try IndexStorage.candidateEntries(hint: rangeLaunchHint, limit: 20, from: databaseURL)
    expect(
        Set(rangeLaunchCandidates.map(\.path)) == Set([photo.path, document.path]),
        "SQLite candidate search should apply size range filters"
    )

    let notEqualLaunchHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch size:!=2000"))
    let notEqualLaunchCandidates = try IndexStorage.candidateEntries(hint: notEqualLaunchHint, limit: 20, from: databaseURL)
    expect(
        notEqualLaunchCandidates.map(\.path) == [photo.path],
        "SQLite candidate search should apply not-equal size filters"
    )

    let duplicateMetricCandidateDatabaseURL = temporaryDirectory.appending(path: "DuplicateMetricCandidates.db")
    try IndexStorage.save(
        IndexSnapshot(rootPath: "/Users/me", entries: duplicateMetricEntries + [folder]),
        to: duplicateMetricCandidateDatabaseURL
    )
    let duplicateSizeCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "sizedupe:")),
        limit: 20,
        from: duplicateMetricCandidateDatabaseURL
    )
    expect(
        Set(duplicateSizeCandidates.map(\.path)) == Set([sameNamePartText.path, sameNamePartMarkdown.path]),
        "SQLite candidate search should apply duplicate size filters"
    )

    let uniqueSizeCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "sizedupe:0")),
        limit: 20,
        from: duplicateMetricCandidateDatabaseURL
    )
    expect(
        Set(uniqueSizeCandidates.map(\.path)) == Set([uniqueDuplicateMetricEntry.path, folder.path]),
        "SQLite candidate search should apply unique size filters"
    )

    let duplicateCreatedDateCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "dcdupe:")),
        limit: 20,
        from: duplicateMetricCandidateDatabaseURL
    )
    expect(
        Set(duplicateCreatedDateCandidates.map(\.path)) == Set([sameNamePartText.path, sameNamePartMarkdown.path]),
        "SQLite candidate search should apply duplicate created-date filters"
    )

    let duplicateModifiedDateCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "dmdupe:")),
        limit: 20,
        from: duplicateMetricCandidateDatabaseURL
    )
    expect(
        Set(duplicateModifiedDateCandidates.map(\.path)) == Set([sameNamePartText.path, sameNamePartMarkdown.path]),
        "SQLite candidate search should apply duplicate modified-date filters"
    )

    let duplicateAccessedDateCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "dadupe:")),
        limit: 20,
        from: duplicateMetricCandidateDatabaseURL
    )
    expect(
        Set(duplicateAccessedDateCandidates.map(\.path)) == Set([sameNamePartText.path, sameNamePartMarkdown.path]),
        "SQLite candidate search should apply duplicate accessed-date filters"
    )

    let duplicateAttributeCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "attribdupe:")),
        limit: 20,
        from: duplicateMetricCandidateDatabaseURL
    )
    expect(
        Set(duplicateAttributeCandidates.map(\.path)) == Set([sameNamePartText.path, sameNamePartMarkdown.path]),
        "SQLite candidate search should apply duplicate attribute filters"
    )

    let unknownSizeCandidateDatabaseURL = temporaryDirectory.appending(path: "UnknownSizeCandidates.db")
    try IndexStorage.save(
        IndexSnapshot(rootPath: "/Users/me", entries: [folder, document]),
        to: unknownSizeCandidateDatabaseURL
    )
    let unknownSizeCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "size:unknown")),
        limit: 20,
        from: unknownSizeCandidateDatabaseURL
    )
    expect(
        unknownSizeCandidates.map(\.path) == [folder.path],
        "SQLite candidate search should apply unknown size filters"
    )

    let emptyCandidateDatabaseURL = temporaryDirectory.appending(path: "EmptyCandidates.db")
    try IndexStorage.save(
        IndexSnapshot(rootPath: "/Users/me", entries: [emptyFile, document, folder, childInFolder]),
        to: emptyCandidateDatabaseURL
    )
    let emptyCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "empty:")),
        limit: 20,
        from: emptyCandidateDatabaseURL
    )
    expect(
        emptyCandidates.map(\.path) == [emptyFile.path],
        "SQLite candidate search should apply empty-entry filters"
    )

    let nonEmptyCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "empty:0")),
        limit: 20,
        from: emptyCandidateDatabaseURL
    )
    expect(
        Set(nonEmptyCandidates.map(\.path)) == Set([document.path, folder.path, childInFolder.path]),
        "SQLite candidate search should apply non-empty-entry filters"
    )

    let todayLaunchHint = SearchEngine.candidateHint(for: SearchRequest(query: "launch dm:today"))
    let todayLaunchCandidates = try IndexStorage.candidateEntries(hint: todayLaunchHint, limit: 20, from: databaseURL)
    expect(
        todayLaunchCandidates.map(\.path) == [photo.path],
        "SQLite candidate search should apply date filters"
    )

    let unknownDateCandidateDatabaseURL = temporaryDirectory.appending(path: "UnknownDateCandidates.db")
    try IndexStorage.save(
        IndexSnapshot(rootPath: "/Users/me", entries: [compactMatch, relativeRecent]),
        to: unknownDateCandidateDatabaseURL
    )
    let unknownDateCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "dm:unknown")),
        limit: 20,
        from: unknownDateCandidateDatabaseURL
    )
    expect(
        unknownDateCandidates.map(\.path) == [compactMatch.path],
        "SQLite candidate search should apply unknown modified-date filters"
    )

    try IndexStorage.upsert(entries: [otherMediaTaggedEntry], rootPath: temporaryDirectory.path, to: databaseURL)
    let mediaTrackCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "track:>5")),
        limit: 20,
        from: databaseURL
    )
    expect(
        mediaTrackCandidates.map(\.path) == [mediaTaggedEntry.path],
        "SQLite candidate search should apply media track filters"
    )

    let mediaYearCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "year:>=2020")),
        limit: 20,
        from: databaseURL
    )
    expect(
        mediaYearCandidates.map(\.path) == [mediaTaggedEntry.path],
        "SQLite candidate search should apply media year filters"
    )

    let mediaArtistCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(query: "artist:Codex", options: SearchOptions(diacriticSensitive: true))
        ),
        limit: 20,
        from: databaseURL
    )
    expect(
        mediaArtistCandidates.map(\.path) == [mediaTaggedEntry.path],
        "SQLite candidate search should apply diacritic-sensitive media text filters"
    )

    let mediaArtistPresenceCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "artist:")),
        limit: 20,
        from: databaseURL
    )
    expect(
        Set(mediaArtistPresenceCandidates.map(\.path)) == Set([mediaTaggedEntry.path, otherMediaTaggedEntry.path]),
        "SQLite candidate search should apply media text presence filters"
    )

    let broadFileListSourceCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "filelistfilename:Offline")),
        limit: 20,
        from: databaseURL
    )
    expect(
        Set(broadFileListSourceCandidates.map(\.path)) == Set([sqliteFileListEntry.path, archiveFileListEntry.path]),
        "SQLite candidate search should keep broad file-list source provenance filters when exact source matching is unsafe"
    )

    let exactFileListSourceCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(
                query: "filelistfilename:\"Offline Media.efu\"",
                options: exactParentChildOptions
            )
        ),
        limit: 20,
        from: databaseURL
    )
    expect(
        exactFileListSourceCandidates.map(\.path) == [sqliteFileListEntry.path],
        "SQLite candidate search should apply exact file-list source name filters"
    )

    let exactFileListSourcePathCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(
            for: SearchRequest(
                query: "filelistfilename:\"/Users/me/File Lists/Offline Media.efu\"",
                options: exactParentChildOptions
            )
        ),
        limit: 20,
        from: databaseURL
    )
    expect(
        exactFileListSourcePathCandidates.map(\.path) == [sqliteFileListEntry.path],
        "SQLite candidate search should apply exact file-list source path filters"
    )

    let fileListSourcePresenceCandidates = try IndexStorage.candidateEntries(
        hint: SearchEngine.candidateHint(for: SearchRequest(query: "filelistfilename:")),
        limit: 20,
        from: databaseURL
    )
    expect(
        Set(fileListSourcePresenceCandidates.map(\.path)) == Set([sqliteFileListEntry.path, archiveFileListEntry.path]),
        "SQLite candidate search should apply file-list source presence filters"
    )

    let offlineOnly = FileEntry(
        path: "/Volumes/Offline/Launch Archive.txt",
        name: "Launch Archive.txt",
        parent: "/Volumes/Offline",
        kind: .file,
        byteSize: 128,
        modifiedAt: Date(timeIntervalSince1970: 3_000)
    )
    let sqliteOnlyCandidates = try IndexStorage.candidateEntries(terms: ["Launch"], limit: 20, from: databaseURL)
    let mergedCandidateResults = SearchEngine.search(
        request: SearchRequest(query: "launch", sortField: .name),
        in: FileIndex(entries: sqliteOnlyCandidates + [offlineOnly]).entries
    )
    expect(
        mergedCandidateResults.entries.contains { $0.path == offlineOnly.path },
        "large-index candidate search should keep enabled file-list entries alongside SQLite candidates"
    )

    try IndexStorage.delete(paths: [photo.path], rootPath: temporaryDirectory.path, from: databaseURL)
    loadedSnapshot = try IndexStorage.load(from: databaseURL)
    expect(
        loadedSnapshot.entries.contains { $0.path == photo.path } == false,
        "SQLite index storage should delete removed paths"
    )

    let profileA = IndexProfile.make(rootPath: "/Volumes/A", name: "A")
    let profileB = IndexProfile.make(rootPath: "/Volumes/B", name: "B")
    expect(
        profileA.id != profileB.id,
        "index profiles should produce distinct IDs for distinct roots"
    )

    var eventProfile = IndexProfile.make(rootPath: "/Volumes/Evented", name: "Evented")
    eventProfile.lastFSEventID = 123_456
    eventProfile.isEnabled = false
    eventProfile.exclusionRules = IndexExclusionRules(
        includeHiddenFiles: false,
        excludedPathPrefixes: ["/Volumes/Evented/Build"],
        excludedNamePatterns: ["*.tmp"],
        excludedExtensions: ["LOG"]
    )
    let encodedEventProfile = try JSONEncoder().encode(eventProfile)
    let decodedEventProfile = try JSONDecoder().decode(IndexProfile.self, from: encodedEventProfile)
    expect(
        decodedEventProfile.lastFSEventID == eventProfile.lastFSEventID,
        "index profiles should persist FSEvents resume IDs"
    )
    expect(
        decodedEventProfile.isEnabled == false,
        "index profiles should persist whether they are included in multi-profile search"
    )
    expect(
        decodedEventProfile.exclusionRules.includeHiddenFiles == false &&
            decodedEventProfile.exclusionRules.excludedPathPrefixes == ["/Volumes/Evented/Build"] &&
            decodedEventProfile.exclusionRules.excludedNamePatterns == ["*.tmp"] &&
            decodedEventProfile.exclusionRules.excludedExtensions == ["log"],
        "index profiles should persist normalized index exclusion rules"
    )

    let legacyProfileJSON = """
    {
      "id": "legacy",
      "name": "Legacy",
      "rootPath": "/Volumes/Legacy",
      "createdAt": 0,
      "updatedAt": 0
    }
    """
    let legacyProfile = try JSONDecoder().decode(IndexProfile.self, from: Data(legacyProfileJSON.utf8))
    expect(
        legacyProfile.isEnabled,
        "legacy index profiles should default to enabled search"
    )

    let profileAURL = try IndexStorage.profileIndexURL(profileID: profileA.id, applicationDirectory: temporaryDirectory)
    let profileBURL = try IndexStorage.profileIndexURL(profileID: profileB.id, applicationDirectory: temporaryDirectory)
    try IndexStorage.save(IndexSnapshot(rootPath: profileA.rootPath, entries: [photo]), to: profileAURL)
    try IndexStorage.save(IndexSnapshot(rootPath: profileB.rootPath, entries: [document]), to: profileBURL)

    let profileASnapshot = try IndexStorage.load(from: profileAURL)
    let profileBSnapshot = try IndexStorage.load(from: profileBURL)
    expect(
        profileASnapshot.entries.map(\.path) == [photo.path] &&
            profileBSnapshot.entries.map(\.path) == [document.path],
        "profile index databases should persist independently"
    )
} catch {
    fputs("Self-test failed: SQLite/index IO threw \(error)\n", stderr)
    exit(1)
}

do {
    let serverPort: UInt16 = 18245
    let server = try QueryHTTPServer(
        port: serverPort,
        searchHandler: { request in
            SearchEngine.search(
                request: request,
                in: [photo, document, folder]
            )
        },
        statusHandler: {
            QueryHTTPServer.Status(
                rootPath: "/Users/me",
                indexedCount: 3,
                resultCount: 0,
                lastIndexedAt: nil,
                statusText: "Ready",
                isIndexing: false,
                isLoadingIndex: true,
                indexFreshnessWarning: "Event history lost"
            )
        }
    )
    defer {
        server.stop()
    }

    Thread.sleep(forTimeInterval: 0.1)

    let statusResponse = try httpGet(port: serverPort, path: "/api/status")
    if !(statusResponse.contains("\"indexedCount\":3") &&
        statusResponse.contains("\"statusText\":\"Ready\"") &&
        statusResponse.contains("\"isIndexing\":false") &&
        statusResponse.contains("\"isLoadingIndex\":true") &&
        statusResponse.contains("\"indexFreshnessWarning\":\"Event history lost\"") &&
        statusResponse.contains("\"isSearching\":false")) {
        fputs("HTTP status response was:\n\(statusResponse)\n", stderr)
    }
    expect(
        statusResponse.contains("\"indexedCount\":3") &&
            statusResponse.contains("\"statusText\":\"Ready\"") &&
            statusResponse.contains("\"isIndexing\":false") &&
            statusResponse.contains("\"isLoadingIndex\":true") &&
            statusResponse.contains("\"indexFreshnessWarning\":\"Event history lost\"") &&
            statusResponse.contains("\"isSearching\":false"),
        "HTTP query service should return status JSON with indexing state"
    )

    let searchResponse = try httpGet(port: serverPort, path: "/api/search?q=launch&limit=2")
    if !(searchResponse.contains("\"totalMatches\":3") && searchResponse.contains("Launch")) {
        fputs("HTTP search response was:\n\(searchResponse)\n", stderr)
    }
    expect(
        searchResponse.contains("\"totalMatches\":3") &&
            searchResponse.contains("Launch") &&
            searchResponse.contains("\"diagnostics\"") &&
            searchResponse.contains("\"source\":\"memory\""),
        "HTTP query service should return search JSON with diagnostics"
    )

    let regexSearchResponse = try httpGet(port: serverPort, path: "/api/search?q=%5ELaunch&regex=true&limit=5")
    expect(
        regexSearchResponse.contains("\"totalMatches\":3") &&
            regexSearchResponse.contains("Launch.JPG") &&
            regexSearchResponse.contains("Launch Notes.md"),
        "HTTP query service should apply the regex search option"
    )

    let offsetSearchResponse = try httpGet(
        port: serverPort,
        path: "/api/search?q=launch&limit=1&offset=1&sort=name&order=asc"
    )
    let offsetDocumentRange = offsetSearchResponse.range(of: "Launch Notes.md")
    let offsetPhotoRange = offsetSearchResponse.range(of: "Launch.JPG")
    expect(
        offsetSearchResponse.contains("\"totalMatches\":3") &&
            offsetSearchResponse.contains("\"limit\":1") &&
            offsetSearchResponse.contains("\"offset\":1") &&
            offsetDocumentRange != nil &&
            offsetPhotoRange == nil,
        "HTTP query service should apply offset windows while preserving total match counts"
    )

    let countSearchResponse = try httpGet(
        port: serverPort,
        path: "/api/search?q=launch%20count%3A1&sort=name&order=asc"
    )
    expect(
        countSearchResponse.contains("\"totalMatches\":3") &&
            countSearchResponse.contains("\"name\":\"Launch\"") &&
            !countSearchResponse.contains("Launch.JPG") &&
            !countSearchResponse.contains("Launch Notes.md"),
        "HTTP query service should apply count: result limits from the query"
    )

    let sortedSearchResponse = try httpGet(
        port: serverPort,
        path: "/api/search?q=file%3A&limit=2&sort=size&order=desc"
    )
    let photoRange = sortedSearchResponse.range(of: "Launch.JPG")
    let documentRange = sortedSearchResponse.range(of: "Launch Notes.md")
    expect(
        sortedSearchResponse.contains("\"sortField\":\"size\"") &&
            sortedSearchResponse.contains("\"sortDirection\":\"descending\"") &&
            photoRange != nil &&
            documentRange != nil &&
            photoRange!.lowerBound < documentRange!.lowerBound,
        "HTTP query service should apply explicit sort and direction parameters"
    )

    let aliasSortedSearchResponse = try httpGet(
        port: serverPort,
        path: "/api/search?q=launch&limit=2&sort=dm&order=descending"
    )
    expect(
        aliasSortedSearchResponse.contains("\"sortField\":\"dateModified\"") &&
            aliasSortedSearchResponse.contains("\"sortDirection\":\"descending\""),
        "HTTP query service should accept Everything-style sort aliases"
    )

    let columnSearchResponse = try httpGet(
        port: serverPort,
        path: "/api/search?q=launch&limit=1&columns=name,path"
    )
    expect(
        columnSearchResponse.contains("\"columns\":[\"name\",\"path\"]") &&
            columnSearchResponse.contains("\"rows\""),
        "HTTP query service should include selected JSON rows when columns are requested"
    )

    let csvSearchResponse = try httpGet(
        port: serverPort,
        path: "/api/search?q=file%3A&limit=1&sort=size&order=desc&format=csv&columns=name,path"
    )
    expect(
        csvSearchResponse.contains("Content-Type: text/csv") &&
            csvSearchResponse.contains("Name,Path") &&
            csvSearchResponse.contains(photo.path),
        "HTTP query service should export selected CSV columns"
    )
} catch {
    fputs("Self-test failed: HTTP query service threw \(error)\n", stderr)
    exit(1)
}

do {
    let serverPort: UInt16 = 18246
    let searchStarted = DispatchSemaphore(value: 0)
    let releaseSearch = DispatchSemaphore(value: 0)
    let searchFinished = DispatchSemaphore(value: 0)
    let searchResult = HTTPResultBox()

    let server = try QueryHTTPServer(
        port: serverPort,
        searchHandler: { _ in
            searchStarted.signal()
            _ = releaseSearch.wait(timeout: .now() + 2)
            return SearchResponse(entries: [], totalMatches: 0)
        },
        statusHandler: {
            QueryHTTPServer.Status(
                rootPath: "/Users/me",
                indexedCount: 3,
                resultCount: 0,
                lastIndexedAt: nil,
                statusText: "Ready",
                isIndexing: false,
                isLoadingIndex: false,
                isSearching: true
            )
        }
    )
    defer {
        server.stop()
    }

    Thread.sleep(forTimeInterval: 0.1)

    DispatchQueue.global(qos: .userInitiated).async {
        do {
            searchResult.set(.success(try httpGet(
                port: serverPort,
                path: "/api/search?q=slow&limit=1",
                timeoutSeconds: 3
            )))
        } catch {
            searchResult.set(.failure(error))
        }
        searchFinished.signal()
    }

    expect(
        searchStarted.wait(timeout: .now() + 1) == .success,
        "HTTP query service should start search requests"
    )

    let statusResponse = try httpGet(port: serverPort, path: "/api/status", timeoutSeconds: 1)
    expect(
        statusResponse.contains("\"indexedCount\":3") &&
            statusResponse.contains("\"statusText\":\"Ready\"") &&
            statusResponse.contains("\"isSearching\":true"),
        "HTTP query service should answer status while a search request is still running"
    )

    releaseSearch.signal()
    expect(
        searchFinished.wait(timeout: .now() + 2) == .success,
        "HTTP query service should finish concurrent search requests"
    )
    switch searchResult.get() {
    case let .success(response):
        expect(
            response.contains("\"totalMatches\":0"),
            "HTTP query service should return completed concurrent search JSON"
        )
    case let .failure(error):
        fputs("Concurrent HTTP search failed: \(error)\n", stderr)
        expect(false, "HTTP query service should not fail concurrent search requests")
    case .none:
        expect(false, "HTTP query service should capture concurrent search results")
    }
} catch {
    fputs("Self-test failed: HTTP query service concurrency threw \(error)\n", stderr)
    exit(1)
}

print("MacThing self-test passed")
