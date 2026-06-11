import AppKit
import Foundation
import MacThingCore
import UniformTypeIdentifiers

enum ResultFilter: String, Codable, CaseIterable, Identifiable, Sendable {
    case all
    case files
    case folders
    case images
    case audio
    case video
    case documents

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all:
            return "All"
        case .files:
            return "Files"
        case .folders:
            return "Folders"
        case .images:
            return "Images"
        case .audio:
            return "Audio"
        case .video:
            return "Video"
        case .documents:
            return "Docs"
        }
    }

    var searchPrefix: String {
        switch self {
        case .all:
            return ""
        case .files:
            return "file:"
        case .folders:
            return "folder:"
        case .images:
            return "file: ext:jpg;jpeg;png;gif;heic;webp;tiff;bmp;svg"
        case .audio:
            return "file: ext:mp3;m4a;wav;aiff;flac;ogg"
        case .video:
            return "file: ext:mp4;mov;m4v;mkv;avi;webm"
        case .documents:
            return "file: ext:pdf;doc;docx;pages;txt;md;rtf;xls;xlsx;csv;ppt;pptx"
        }
    }
}

enum ResultColumn: String, Codable, CaseIterable, Identifiable, Sendable {
    case name
    case path
    case extensionName = "extension"
    case kind
    case dateModified
    case size
    case dateCreated
    case dateAccessed
    case dateIndexed
    case runCount
    case dateRun
    case attributes
    case title
    case artist
    case album
    case comment
    case genre
    case track
    case year

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .name:
            return "Name"
        case .path:
            return "Path"
        case .extensionName:
            return "Extension"
        case .kind:
            return "Kind"
        case .dateModified:
            return "Modified"
        case .size:
            return "Size"
        case .dateCreated:
            return "Created"
        case .dateAccessed:
            return "Accessed"
        case .dateIndexed:
            return "Indexed"
        case .runCount:
            return "Run Count"
        case .dateRun:
            return "Date Run"
        case .attributes:
            return "Attributes"
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

    var sortField: SearchSortField {
        switch self {
        case .name:
            return .name
        case .path:
            return .path
        case .extensionName:
            return .extensionName
        case .kind:
            return .kind
        case .dateModified:
            return .dateModified
        case .size:
            return .size
        case .dateCreated:
            return .dateCreated
        case .dateAccessed:
            return .dateAccessed
        case .dateIndexed:
            return .dateIndexed
        case .runCount:
            return .runCount
        case .dateRun:
            return .dateRun
        case .attributes:
            return .attributes
        case .title:
            return .title
        case .artist:
            return .artist
        case .album:
            return .album
        case .comment:
            return .comment
        case .genre:
            return .genre
        case .track:
            return .track
        case .year:
            return .year
        }
    }

    static let defaults: Set<ResultColumn> = [.name, .path, .kind, .dateModified, .size]
}

private struct PersistedSearchSettings: Codable {
    var rootPath: String
    var query: String
    var activeFilter: ResultFilter
    var sortField: SearchSortField
    var sortDirection: SearchSortDirection
    var searchOptions: SearchOptions
    var visibleColumns: Set<ResultColumn>?
    var activeProfileID: String?
    var globalHotkeyChoice: GlobalHotkeyChoice?
    var launchAtLogin: Bool?
}

private struct PersistedIndexLoadState: Sendable {
    var activeSnapshot: IndexSnapshot?
    var auxiliaryProfileEntriesByID: [String: [FileEntry]]
    var activeIndexLoadFailed: Bool
}

private final class QueryServiceState: @unchecked Sendable {
    private struct Snapshot {
        var rootPath = ""
        var entries: [FileEntry] = []
        var indexURLs: [URL] = []
        var fileListEntries: [FileEntry] = []
        var resultCount = 0
        var lastIndexedAt: Date?
        var statusText = ""
        var isIndexing = false
        var sortField: SearchSortField = .relevance
        var sortDirection: SearchSortDirection = .ascending
        var options = SearchOptions()
    }

    private let lock = NSLock()
    private var snapshot = Snapshot()

    func update(
        rootPath: String,
        entries: [FileEntry],
        indexURLs: [URL],
        fileListEntries: [FileEntry],
        resultCount: Int,
        lastIndexedAt: Date?,
        statusText: String,
        isIndexing: Bool,
        sortField: SearchSortField,
        sortDirection: SearchSortDirection,
        options: SearchOptions
    ) {
        lock.lock()
        snapshot = Snapshot(
            rootPath: rootPath,
            entries: entries,
            indexURLs: indexURLs,
            fileListEntries: fileListEntries,
            resultCount: resultCount,
            lastIndexedAt: lastIndexedAt,
            statusText: statusText,
            isIndexing: isIndexing,
            sortField: sortField,
            sortDirection: sortDirection,
            options: options
        )
        lock.unlock()
    }

    func status() -> QueryHTTPServer.Status {
        lock.lock()
        let current = snapshot
        lock.unlock()

        return QueryHTTPServer.Status(
            rootPath: current.rootPath,
            indexedCount: current.entries.count,
            resultCount: current.resultCount,
            lastIndexedAt: current.lastIndexedAt,
            statusText: current.statusText,
            isIndexing: current.isIndexing
        )
    }

    func search(request: SearchRequest) -> SearchResponse {
        lock.lock()
        let current = snapshot
        lock.unlock()

        if let databaseResponse = SearchStore.databaseBackedSearch(
            request: request,
            entries: current.entries,
            indexURLs: current.indexURLs,
            activeFileListEntries: current.fileListEntries
        ) {
            return databaseResponse
        }

        return SearchEngine.search(request: request, in: current.entries)
    }
}

struct SearchBookmark: Codable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var query: String
    var activeFilter: ResultFilter
    var sortField: SearchSortField
    var sortDirection: SearchSortDirection
    var searchOptions: SearchOptions
    var createdAt: Date
}

struct SearchHistoryItem: Codable, Identifiable, Sendable {
    let id: UUID
    var query: String
    var lastUsedAt: Date
    var useCount: Int
}

struct UserSearchFilter: Codable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var query: String
    var createdAt: Date
}

@MainActor
final class SearchStore: ObservableObject {
    @Published var query = ""
    @Published var rootPath = NSHomeDirectory()
    @Published var entries: [FileEntry] = []
    @Published var results: [FileEntry] = []
    @Published var totalMatches = 0
    @Published var searchWarnings: [String] = []
    @Published var selectedPath: String?
    @Published var isIndexing = false
    @Published var statusText = "Ready"
    @Published var lastIndexedAt: Date?
    @Published var activeFilter: ResultFilter = .all
    @Published var sortField: SearchSortField = .relevance
    @Published var sortDirection: SearchSortDirection = .ascending
    @Published var searchOptions = SearchOptions()
    @Published var bookmarks: [SearchBookmark] = []
    @Published var visibleColumns = ResultColumn.defaults
    @Published var volumeProfiles: [VolumeProfile] = []
    @Published var permissionIssues: [PermissionIssue] = []
    @Published var indexProfiles: [IndexProfile] = []
    @Published var activeProfileID: String?
    @Published var globalHotkeyChoice: GlobalHotkeyChoice = .optionSpace
    @Published var launchAtLogin = false
    @Published var fileListSources: [FileListSource] = []
    @Published var searchHistory: [SearchHistoryItem] = []
    @Published var userFilters: [UserSearchFilter] = []

    private var searchTask: Task<Void, Never>?
    private var historyTask: Task<Void, Never>?
    private var indexTask: Task<Void, Never>?
    private var loadIndexTask: Task<Void, Never>?
    private var monitorReindexTasksByProfileID: [String: Task<Void, Never>] = [:]
    private var fileSystemMonitorsByProfileID: [String: FileSystemMonitor] = [:]
    private var queryHTTPServer: QueryHTTPServer?
    private var globalHotkeyController: GlobalHotkeyController?
    private var compactSearchWindowController: CompactSearchWindowController?
    private let queryServiceState = QueryServiceState()
    private var fileIndex = FileIndex()
    private var auxiliaryProfileEntriesByID: [String: [FileEntry]] = [:]
    private var pendingFileSystemChangesByProfileID: [String: [String: FileSystemChange]] = [:]
    private let settingsKey = "MacThing.SearchSettings.v1"
    private let bookmarksKey = "MacThing.SearchBookmarks.v1"
    private let historyKey = "MacThing.SearchHistory.v1"
    private let userFiltersKey = "MacThing.UserFilters.v1"
    private let profilesKey = "MacThing.IndexProfiles.v1"

    var selectedEntry: FileEntry? {
        guard let selectedPath else {
            return nil
        }
        return results.first { $0.path == selectedPath }
    }

    var orderedVisibleColumns: [ResultColumn] {
        ResultColumn.allCases.filter { visibleColumns.contains($0) }
    }

    var activeIndexProfile: IndexProfile? {
        guard let activeProfileID else {
            return nil
        }
        return indexProfiles.first { $0.id == activeProfileID }
    }

    var enabledProfileCount: Int {
        indexProfiles.filter(\.isEnabled).count
    }

    private var activeIndexURL: URL? {
        guard let activeProfileID else {
            return try? IndexStorage.defaultIndexURL()
        }
        return try? IndexStorage.profileIndexURL(profileID: activeProfileID)
    }

    private var enabledProfileIndexURLs: [URL] {
        indexProfiles
            .filter(\.isEnabled)
            .compactMap { try? IndexStorage.profileIndexURL(profileID: $0.id) }
    }

    var activeIndexExclusionRules: IndexExclusionRules {
        activeIndexProfile?.exclusionRules ?? IndexExclusionRules()
    }

    var activeExcludedPathPrefixes: [String] {
        activeIndexExclusionRules.excludedPathPrefixes.sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    var activeExcludedNamePatterns: [String] {
        activeIndexExclusionRules.excludedNamePatterns.sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    var activeExcludedExtensions: [String] {
        activeIndexExclusionRules.excludedExtensions.sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    private var runtimeExcludedPathPrefixes: [String] {
        runtimeExcludedPathPrefixes(forProfileID: activeProfileID)
    }

    private var effectiveExcludedPathPrefixes: [String] {
        guard let profile = activeIndexProfile else {
            return runtimeExcludedPathPrefixes
        }
        return effectiveExcludedPathPrefixes(for: profile)
    }

    private func scanConfiguration(rootURL: URL) -> ScanConfiguration {
        guard let profile = activeIndexProfile else {
            return ScanConfiguration(rootURL: rootURL)
        }
        return scanConfiguration(rootURL: rootURL, profile: profile)
    }

    private func scanConfiguration(rootURL: URL, profile: IndexProfile) -> ScanConfiguration {
        ScanConfiguration(
            rootURL: rootURL,
            exclusionRules: profile.exclusionRules,
            runtimeExcludedPathPrefixes: runtimeExcludedPathPrefixes(forProfileID: profile.id)
        )
    }

    private func runtimeExcludedPathPrefixes(forProfileID profileID: String?) -> [String] {
        var excludedPaths = Self.applicationRuntimeExcludedPathPrefixes()
        if let profileID,
           let indexURL = try? IndexStorage.profileIndexURL(profileID: profileID) {
            excludedPaths.append(indexURL.deletingLastPathComponent().path)
        }
        return IndexExclusionRules(excludedPathPrefixes: excludedPaths).excludedPathPrefixes
    }

    private nonisolated static func applicationRuntimeExcludedPathPrefixes() -> [String] {
        var paths: [String] = []
        if let supportDirectory = try? IndexStorage.applicationSupportDirectory() {
            paths.append(supportDirectory.path)
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        paths.append(home.appending(path: "Library/Preferences/com.shibuki.MacThing.plist").path)
        paths.append(home.appending(path: "Library/Preferences/MacThing.plist").path)
        paths.append(home.appending(path: "Library/Caches/com.shibuki.MacThing").path)
        paths.append(home.appending(path: "Library/Saved Application State/com.shibuki.MacThing.savedState").path)
        return paths
    }

    private func effectiveExcludedPathPrefixes(for profile: IndexProfile) -> [String] {
        IndexExclusionRules(
            excludedPathPrefixes: profile.exclusionRules.excludedPathPrefixes +
                runtimeExcludedPathPrefixes(forProfileID: profile.id)
        ).excludedPathPrefixes
    }

    init() {
        loadSettings()
        loadBookmarks()
        loadSearchHistory()
        loadUserFilters()
        loadFileListSources()
        loadIndexProfiles()
        ensureActiveProfile()
        statusText = "Loading saved index..."
        refreshVolumes()
        refreshPermissionDiagnostics()
        refreshLaunchAtLoginState()
        updateQueryServiceState()
        startQueryService()
        startGlobalHotkey()
        loadPersistedIndexInBackground()
    }

    func setQuery(_ value: String) {
        query = value
        saveSettings()
        updateQueryServiceState()
        scheduleSearch()
        scheduleHistoryRecording(for: value)
    }

    func setFilter(_ filter: ResultFilter) {
        activeFilter = filter
        saveSettings()
        updateQueryServiceState()
        scheduleSearch()
    }

    func setSort(_ field: SearchSortField) {
        if sortField == field {
            sortDirection = sortDirection.toggled
        } else {
            sortField = field
            sortDirection = Self.defaultDirection(for: field)
        }
        saveSettings()
        updateQueryServiceState()
        scheduleSearch()
    }

    func toggleMatchPath() {
        searchOptions.matchPath.toggle()
        saveSettings()
        updateQueryServiceState()
        scheduleSearch()
    }

    func toggleFuzzyMatching() {
        searchOptions.fuzzyMatching.toggle()
        saveSettings()
        updateQueryServiceState()
        scheduleSearch()
    }

    func toggleCaseSensitive() {
        searchOptions.caseSensitive.toggle()
        saveSettings()
        updateQueryServiceState()
        scheduleSearch()
    }

    func toggleRegexMatching() {
        searchOptions.regexMatching.toggle()
        saveSettings()
        updateQueryServiceState()
        scheduleSearch()
    }

    func toggleWholeWordMatching() {
        searchOptions.wholeWordMatching.toggle()
        saveSettings()
        updateQueryServiceState()
        scheduleSearch()
    }

    func toggleDiacriticSensitive() {
        searchOptions.diacriticSensitive.toggle()
        saveSettings()
        updateQueryServiceState()
        scheduleSearch()
    }

    func toggleColumn(_ column: ResultColumn) {
        if visibleColumns.contains(column), visibleColumns.count > 1 {
            visibleColumns.remove(column)
        } else {
            visibleColumns.insert(column)
        }
        saveSettings()
    }

    func refreshVolumes() {
        volumeProfiles = VolumeProfileProvider.mountedVolumes()
    }

    func indexVolume(_ profile: VolumeProfile) {
        activateOrCreateProfile(rootPath: profile.path, name: profile.displayName)
        reindexCurrentRoot()
    }

    func refreshPermissionDiagnostics() {
        permissionIssues = PermissionDiagnostics.fullDiskAccessIssues()
    }

    func openFullDiskAccessSettings() {
        PermissionDiagnostics.openFullDiskAccessSettings()
    }

    func chooseRoot() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Index"
        panel.directoryURL = URL(fileURLWithPath: rootPath)

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        rootPath = url.path
        activateOrCreateProfile(rootPath: url.path, name: url.lastPathComponent.nonEmpty ?? url.path)
        index(rootURL: url)
    }

    func activateProfile(_ profile: IndexProfile) {
        loadIndexTask?.cancel()
        activeProfileID = profile.id
        rootPath = profile.rootPath
        saveSettings()
        loadPersistedIndex()
        startMonitoringEnabledProfiles()
        scheduleSearch()
        statusText = "Profile: \(profile.displayName)"
    }

    func currentProfileLabel(_ profile: IndexProfile) -> String {
        var label = profile.displayName
        if profile.id == activeProfileID {
            label += " *"
        }
        if !profile.isEnabled {
            label += " off"
        }
        return label
    }

    func addProfileForCurrentRoot() {
        activateOrCreateProfile(rootPath: rootPath, name: URL(fileURLWithPath: rootPath).lastPathComponent.nonEmpty ?? rootPath)
        statusText = "Profile added"
    }

    func removeProfile(_ profile: IndexProfile) {
        guard indexProfiles.count > 1 else {
            statusText = "Keep at least one profile"
            return
        }

        loadIndexTask?.cancel()
        indexProfiles.removeAll { $0.id == profile.id }
        auxiliaryProfileEntriesByID.removeValue(forKey: profile.id)
        normalizeProfileEnabledState()
        if activeProfileID == profile.id {
            activeProfileID = indexProfiles.first?.id
            rootPath = indexProfiles.first?.rootPath ?? NSHomeDirectory()
            loadPersistedIndex()
            startMonitoringEnabledProfiles()
            scheduleSearch()
        }
        saveIndexProfiles()
        saveSettings()
        startMonitoringEnabledProfiles()
        statusText = "Profile removed"
    }

    func toggleProfileSearch(_ profile: IndexProfile) {
        guard let index = indexProfiles.firstIndex(where: { $0.id == profile.id }) else {
            return
        }

        if indexProfiles[index].isEnabled && enabledProfileCount == 1 {
            statusText = "Keep at least one searchable profile"
            return
        }

        loadIndexTask?.cancel()
        indexProfiles[index].isEnabled.toggle()
        indexProfiles[index].updatedAt = Date()
        let updatedProfile = indexProfiles[index]

        if updatedProfile.isEnabled {
            loadAuxiliaryProfileIndex(updatedProfile)
        } else {
            auxiliaryProfileEntriesByID.removeValue(forKey: updatedProfile.id)
        }

        saveIndexProfiles()
        rebuildEntriesFromIndexes()
        updateQueryServiceState()
        startMonitoringEnabledProfiles()
        scheduleSearch()
        statusText = updatedProfile.isEnabled ? "Profile included in search" : "Profile excluded from search"
    }

    func reindexCurrentRoot() {
        index(rootURL: URL(fileURLWithPath: rootPath))
    }

    func chooseExcludedPaths() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Exclude"
        panel.directoryURL = URL(fileURLWithPath: rootPath)

        guard panel.runModal() == .OK else {
            return
        }

        let paths = panel.urls.compactMap { url in
            normalizedExclusionPath(url.path)
        }
        addExcludedPaths(paths)
    }

    func excludeSelectedPath() {
        guard let selectedEntry else {
            statusText = "Select an item first"
            return
        }
        guard let path = normalizedExclusionPath(selectedEntry.path) else {
            return
        }
        addExcludedPaths([path])
    }

    func excludeSelectedExtension() {
        guard let selectedEntry else {
            statusText = "Select an item first"
            return
        }
        guard let extensionName = IndexExclusionRules.normalizedExtension(selectedEntry.extensionName) else {
            statusText = "Selected item has no extension"
            return
        }
        updateActiveProfileExclusionRules(status: "Extension excluded") { rules in
            rules.excludedExtensions.insert(extensionName)
        }
    }

    func addExcludedNamePattern() {
        let alert = NSAlert()
        alert.messageText = "Exclude Name Pattern"
        alert.informativeText = "Use wildcards such as *.tmp or node_modules."
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(string: "")
        field.placeholderString = "*.tmp"
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = field

        guard alert.runModal() == .alertFirstButtonReturn,
              let pattern = IndexExclusionRules.normalizedNamePattern(field.stringValue) else {
            return
        }

        updateActiveProfileExclusionRules(status: "Name pattern excluded") { rules in
            rules.excludedNamePatterns.append(pattern)
        }
    }

    func toggleIndexHiddenFiles() {
        updateActiveProfileExclusionRules(status: "Hidden-file indexing changed") { rules in
            rules.includeHiddenFiles.toggle()
        }
    }

    func removeExcludedPath(_ path: String) {
        guard let normalizedPath = IndexExclusionRules.normalizedPathPrefix(for: path) else {
            return
        }
        updateActiveProfileExclusionRules(status: "Excluded path removed") { rules in
            rules.excludedPathPrefixes.removeAll { $0 == normalizedPath }
        }
    }

    func removeExcludedNamePattern(_ pattern: String) {
        updateActiveProfileExclusionRules(status: "Name pattern removed") { rules in
            rules.excludedNamePatterns.removeAll { $0.caseInsensitiveCompare(pattern) == .orderedSame }
        }
    }

    func removeExcludedExtension(_ extensionName: String) {
        guard let normalizedExtension = IndexExclusionRules.normalizedExtension(extensionName) else {
            return
        }
        updateActiveProfileExclusionRules(status: "Extension rule removed") { rules in
            rules.excludedExtensions.remove(normalizedExtension)
        }
    }

    func clearIndexExclusions() {
        updateActiveProfileExclusionRules(status: "Index exclusions cleared") { rules in
            rules = IndexExclusionRules()
        }
    }

    func openSelected() {
        guard let selectedEntry else {
            return
        }
        recordRun(for: selectedEntry)
        NSWorkspace.shared.open(URL(fileURLWithPath: selectedEntry.path))
    }

    func openSelectedOrFirst() {
        if selectedEntry == nil {
            selectedPath = results.first?.path
        }
        openSelected()
    }

    func moveSelection(offset: Int) {
        guard !results.isEmpty else {
            selectedPath = nil
            return
        }

        let currentIndex: Int
        if let selectedPath,
           let index = results.firstIndex(where: { $0.path == selectedPath }) {
            currentIndex = index
        } else {
            currentIndex = offset >= 0 ? -1 : results.count
        }

        let nextIndex = min(max(currentIndex + offset, 0), results.count - 1)
        selectedPath = results[nextIndex].path
    }

    func showCompactSearch() {
        if compactSearchWindowController == nil {
            compactSearchWindowController = CompactSearchWindowController(store: self)
        }

        compactSearchWindowController?.show()
    }

    func showMainWindow() {
        NSApp.activate()
        let mainSearchWindow = NSApp.windows.first { window in
            window.canBecomeKey && window.title != CompactSearchWindowController.windowTitle
        }
        mainSearchWindow?.makeKeyAndOrderFront(nil)
    }

    @discardableResult
    func runSearchCommandIfNeeded() -> Bool {
        guard let command = EverythingSearchCommand.parse(query) else {
            return false
        }

        runSearchCommand(command)
        return true
    }

    private func runSearchCommand(_ command: EverythingSearchCommand) {
        switch command {
        case .close:
            setQuery("")
            NSApp.keyWindow?.orderOut(nil)
            statusText = "Search window closed"
        case .closeAll:
            setQuery("")
            NSApp.windows
                .filter { $0.canBecomeKey }
                .forEach { $0.orderOut(nil) }
            statusText = "Search windows closed"
        case .quit:
            setQuery("")
            NSApp.terminate(nil)
        case .rebuild:
            setQuery("")
            reindexCurrentRoot()
        case let .update(path):
            setQuery("")
            updateIndex(path: path)
        case .home:
            setQuery("")
            setFilter(.all)
            sortField = .relevance
            sortDirection = .ascending
            saveSettings()
            scheduleSearch()
            statusText = "Home search"
        case .about:
            setQuery("")
            NSApp.orderFrontStandardAboutPanel(nil)
            statusText = "About MacThing"
        case .options:
            setQuery("")
            showMainWindow()
            statusText = "Options are available from the toolbar menus"
        case .help:
            setQuery("")
            statusText = "Commands: /close, /closeall, /rebuild, /update, /quit"
        case let .unsupported(command):
            statusText = "Unsupported command: \(command)"
        }
    }

    private func updateIndex(path rawPath: String?) {
        guard let rawPath, !rawPath.isEmpty else {
            reindexCurrentRoot()
            return
        }

        let path = URL(fileURLWithPath: rawPath)
            .standardizedFileURL
            .path
        guard let profile = enabledIndexProfile(containing: path) else {
            statusText = "Update path is outside indexed roots"
            return
        }

        let change = FileSystemChange(
            path: path,
            flags: 0,
            eventID: FileSystemMonitor.currentEventID()
        )
        statusText = "Updating \(URL(fileURLWithPath: path).lastPathComponent)"
        applyFileSystemChanges(changes: [change], profileID: profile.id)
    }

    private func enabledIndexProfile(containing path: String) -> IndexProfile? {
        indexProfiles
            .filter(\.isEnabled)
            .filter { profile in
                path == profile.rootPath || path.hasPrefix(profile.rootPath + "/")
            }
            .max { lhs, rhs in
                lhs.rootPath.count < rhs.rootPath.count
            }
    }

    func setGlobalHotkeyChoice(_ choice: GlobalHotkeyChoice) {
        globalHotkeyChoice = choice
        saveSettings()

        if globalHotkeyController?.register(choice) == false {
            statusText = "Hotkey unavailable"
        } else {
            statusText = choice == .disabled ? "Hotkey disabled" : "Hotkey: \(choice.displayName)"
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = enabled
        saveSettings()

        guard LaunchAtLoginController.isSupportedBundle else {
            statusText = "Launch at login needs app bundle"
            return
        }

        if LaunchAtLoginController.setEnabled(enabled) {
            launchAtLogin = LaunchAtLoginController.isEnabled
            saveSettings()
            statusText = enabled ? "Launch at login enabled" : "Launch at login disabled"
        } else {
            launchAtLogin = LaunchAtLoginController.isEnabled
            saveSettings()
            statusText = "Launch at login unavailable"
        }
    }

    func revealSelected() {
        guard let selectedEntry else {
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: selectedEntry.path)])
    }

    func copySelectedPath() {
        guard let selectedEntry else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(selectedEntry.path, forType: .string)
        statusText = "Copied path"
    }

    func exportVisibleResults() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "MacThing Results.csv"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try ResultExporter.csv(entries: results).write(to: url, atomically: true, encoding: .utf8)
            statusText = "Exported \(results.count.formatted()) results"
        } catch {
            statusText = "Export failed"
        }
    }

    func importFileList() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        panel.prompt = "Import"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let importedEntries = FileListCodec.parseEFU(text)
            guard !importedEntries.isEmpty else {
                statusText = "No file-list entries"
                return
            }

            let source = FileListSource(
                name: url.lastPathComponent,
                originalPath: url.path,
                entries: importedEntries.map {
                    $0.markingFileListSource(name: url.lastPathComponent, path: url.path)
                }
            )
            fileListSources.removeAll { $0.originalPath == source.originalPath }
            fileListSources.insert(source, at: 0)
            saveFileListSources()
            rebuildEntriesFromIndexes()
            lastIndexedAt = Date()
            statusText = "Imported \(importedEntries.count.formatted()) file-list items"
            updateQueryServiceState()
            scheduleSearch()
        } catch {
            statusText = "Import failed"
        }
    }

    func toggleFileListSource(_ source: FileListSource) {
        guard let index = fileListSources.firstIndex(where: { $0.id == source.id }) else {
            return
        }

        fileListSources[index].isEnabled.toggle()
        fileListSources[index].updatedAt = Date()
        saveFileListSources()
        rebuildEntriesFromIndexes()
        updateQueryServiceState()
        scheduleSearch()
        statusText = fileListSources[index].isEnabled ? "File list enabled" : "File list disabled"
    }

    func refreshFileListSource(_ source: FileListSource) {
        guard let index = fileListSources.firstIndex(where: { $0.id == source.id }) else {
            return
        }

        do {
            let text = try String(contentsOfFile: source.originalPath, encoding: .utf8)
            let refreshedEntries = FileListCodec.parseEFU(text)
            guard !refreshedEntries.isEmpty else {
                statusText = "No file-list entries"
                return
            }

            let sourceName = fileListSources[index].displayName
            let sourcePath = fileListSources[index].originalPath
            fileListSources[index].entries = refreshedEntries.map {
                $0.markingFileListSource(name: sourceName, path: sourcePath)
            }
            fileListSources[index].updatedAt = Date()
            saveFileListSources()
            rebuildEntriesFromIndexes()
            updateQueryServiceState()
            scheduleSearch()
            statusText = "File list refreshed"
        } catch {
            statusText = "Refresh failed"
        }
    }

    func removeFileListSource(_ source: FileListSource) {
        fileListSources.removeAll { $0.id == source.id }
        saveFileListSources()
        rebuildEntriesFromIndexes()
        updateQueryServiceState()
        scheduleSearch()
        statusText = "File list removed"
    }

    func addBookmark() {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let name: String
        if trimmedQuery.isEmpty {
            name = "\(activeFilter.displayName) - \(sortField.displayName)"
        } else {
            name = trimmedQuery
        }

        let bookmark = SearchBookmark(
            id: UUID(),
            name: name,
            query: query,
            activeFilter: activeFilter,
            sortField: sortField,
            sortDirection: sortDirection,
            searchOptions: searchOptions,
            createdAt: Date()
        )

        bookmarks.removeAll { existing in
            existing.query == bookmark.query &&
                existing.activeFilter == bookmark.activeFilter &&
                existing.sortField == bookmark.sortField &&
                existing.sortDirection == bookmark.sortDirection &&
                existing.searchOptions == bookmark.searchOptions
        }
        bookmarks.insert(bookmark, at: 0)
        saveBookmarks()
        statusText = "Bookmark added"
    }

    func applyHistoryItem(_ item: SearchHistoryItem) {
        query = item.query
        saveSettings()
        recordSearchHistory(item.query)
        updateQueryServiceState()
        scheduleSearch()
        statusText = "History applied"
    }

    func removeHistoryItem(_ item: SearchHistoryItem) {
        searchHistory.removeAll { $0.id == item.id }
        saveSearchHistory()
        statusText = "History removed"
    }

    func clearSearchHistory() {
        searchHistory.removeAll()
        saveSearchHistory()
        statusText = "History cleared"
    }

    func addUserFilter() {
        let expression = Self.effectiveQuery(userQuery: query, filter: activeFilter)
        guard !expression.isEmpty else {
            statusText = "Filter needs a query"
            return
        }

        let name = query.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ??
            activeFilter.displayName
        let filter = UserSearchFilter(
            id: UUID(),
            name: name,
            query: expression,
            createdAt: Date()
        )

        userFilters.removeAll { $0.query == filter.query }
        userFilters.insert(filter, at: 0)
        trimUserFilters()
        saveUserFilters()
        statusText = "Filter added"
    }

    func applyUserFilter(_ filter: UserSearchFilter) {
        query = filter.query
        activeFilter = .all
        saveSettings()
        recordSearchHistory(filter.query)
        updateQueryServiceState()
        scheduleSearch()
        statusText = "Filter applied"
    }

    func removeUserFilter(_ filter: UserSearchFilter) {
        userFilters.removeAll { $0.id == filter.id }
        saveUserFilters()
        statusText = "Filter removed"
    }

    func applyBookmark(_ bookmark: SearchBookmark) {
        query = bookmark.query
        activeFilter = bookmark.activeFilter
        sortField = bookmark.sortField
        sortDirection = bookmark.sortDirection
        searchOptions = bookmark.searchOptions
        saveSettings()
        updateQueryServiceState()
        scheduleSearch()
        statusText = "Bookmark applied"
    }

    func removeBookmark(_ bookmark: SearchBookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        saveBookmarks()
        statusText = "Bookmark removed"
    }

    private func loadPersistedIndex() {
        loadIndexTask?.cancel()
        let state = Self.loadPersistedIndexState(
            indexProfiles: indexProfiles,
            activeProfileID: activeProfileID,
            activeIndexURL: activeIndexURL
        )
        applyPersistedIndexState(state)
    }

    private func loadPersistedIndexInBackground() {
        loadIndexTask?.cancel()

        let indexProfiles = indexProfiles
        let activeProfileID = activeProfileID
        let activeIndexURL = activeIndexURL

        loadIndexTask = Task { [weak self] in
            let state = await Task.detached(priority: .userInitiated) {
                Self.loadPersistedIndexState(
                    indexProfiles: indexProfiles,
                    activeProfileID: activeProfileID,
                    activeIndexURL: activeIndexURL
                )
            }.value

            guard let self, !Task.isCancelled else {
                return
            }

            self.applyPersistedIndexState(state)
            self.loadIndexTask = nil
            self.startMonitoringEnabledProfiles()
            self.scheduleSearch()
        }
    }

    private nonisolated static func loadPersistedIndexState(
        indexProfiles: [IndexProfile],
        activeProfileID: String?,
        activeIndexURL: URL?
    ) -> PersistedIndexLoadState {
        var auxiliaryProfileEntriesByID: [String: [FileEntry]] = [:]

        for profile in indexProfiles where profile.isEnabled && profile.id != activeProfileID {
            guard let indexURL = try? IndexStorage.profileIndexURL(profileID: profile.id),
                  FileManager.default.fileExists(atPath: indexURL.path),
                  let snapshot = try? IndexStorage.load(from: indexURL) else {
                continue
            }
            auxiliaryProfileEntriesByID[profile.id] = snapshot.entries
        }

        guard let indexURL = activeIndexURL else {
            return PersistedIndexLoadState(
                activeSnapshot: nil,
                auxiliaryProfileEntriesByID: auxiliaryProfileEntriesByID,
                activeIndexLoadFailed: false
            )
        }

        let legacyURL = try? IndexStorage.defaultIndexURL()
        let shouldMigrateLegacy = indexProfiles.count == 1
        let loadURL: URL?
        if FileManager.default.fileExists(atPath: indexURL.path) {
            loadURL = indexURL
        } else if shouldMigrateLegacy,
                  let legacyURL,
                  legacyURL.path != indexURL.path,
                  FileManager.default.fileExists(atPath: legacyURL.path) {
            loadURL = legacyURL
        } else {
            loadURL = nil
        }

        guard let loadURL else {
            return PersistedIndexLoadState(
                activeSnapshot: nil,
                auxiliaryProfileEntriesByID: auxiliaryProfileEntriesByID,
                activeIndexLoadFailed: false
            )
        }

        do {
            let snapshot = try IndexStorage.load(from: loadURL)
            if loadURL.path != indexURL.path {
                try? IndexStorage.save(snapshot, to: indexURL)
            }
            return PersistedIndexLoadState(
                activeSnapshot: snapshot,
                auxiliaryProfileEntriesByID: auxiliaryProfileEntriesByID,
                activeIndexLoadFailed: false
            )
        } catch {
            return PersistedIndexLoadState(
                activeSnapshot: nil,
                auxiliaryProfileEntriesByID: auxiliaryProfileEntriesByID,
                activeIndexLoadFailed: true
            )
        }
    }

    private func applyPersistedIndexState(_ state: PersistedIndexLoadState) {
        auxiliaryProfileEntriesByID = state.auxiliaryProfileEntriesByID

        guard let snapshot = state.activeSnapshot else {
            clearLoadedIndex(status: state.activeIndexLoadFailed ? "Index could not be loaded" : "No index")
            return
        }

        rootPath = snapshot.rootPath
        fileIndex.replaceAll(snapshot.entries)
        rebuildEntriesFromIndexes()
        lastIndexedAt = snapshot.createdAt
        statusText = "\(entries.count.formatted()) items\(enabledProfileCount > 1 ? " across \(enabledProfileCount) profiles" : "")"
        updateQueryServiceState()
    }

    private func clearLoadedIndex(status: String) {
        fileIndex.replaceAll([])
        rebuildEntriesFromIndexes()
        results = []
        totalMatches = 0
        lastIndexedAt = nil
        statusText = entries.isEmpty ? status : "\(entries.count.formatted()) items"
        updateQueryServiceState()
    }

    private func loadSettings() {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(PersistedSearchSettings.self, from: data) else {
            return
        }

        rootPath = settings.rootPath
        query = settings.query
        activeFilter = settings.activeFilter
        sortField = settings.sortField
        sortDirection = settings.sortDirection
        searchOptions = settings.searchOptions
        activeProfileID = settings.activeProfileID
        globalHotkeyChoice = settings.globalHotkeyChoice ?? GlobalHotkeyChoice.recommended
        launchAtLogin = settings.launchAtLogin ?? false
        if let visibleColumns = settings.visibleColumns, !visibleColumns.isEmpty {
            self.visibleColumns = visibleColumns
        }
    }

    private func loadIndexProfiles() {
        guard let data = UserDefaults.standard.data(forKey: profilesKey),
              let savedProfiles = try? JSONDecoder().decode([IndexProfile].self, from: data) else {
            return
        }
        indexProfiles = savedProfiles
        normalizeProfileEnabledState()
    }

    private func loadBookmarks() {
        guard let data = UserDefaults.standard.data(forKey: bookmarksKey),
              let savedBookmarks = try? JSONDecoder().decode([SearchBookmark].self, from: data) else {
            return
        }
        bookmarks = savedBookmarks
    }

    private func loadSearchHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let savedHistory = try? JSONDecoder().decode([SearchHistoryItem].self, from: data) else {
            return
        }
        searchHistory = Array(savedHistory.prefix(80))
    }

    private func loadUserFilters() {
        guard let data = UserDefaults.standard.data(forKey: userFiltersKey),
              let savedFilters = try? JSONDecoder().decode([UserSearchFilter].self, from: data) else {
            return
        }
        userFilters = Array(savedFilters.prefix(40))
    }

    private func loadFileListSources() {
        guard let url = try? FileListSourceStorage.defaultURL(),
              let sources = try? FileListSourceStorage.load(from: url) else {
            return
        }
        fileListSources = sources
    }

    private func saveSettings() {
        let settings = PersistedSearchSettings(
            rootPath: rootPath,
            query: query,
            activeFilter: activeFilter,
            sortField: sortField,
            sortDirection: sortDirection,
            searchOptions: searchOptions,
            visibleColumns: visibleColumns,
            activeProfileID: activeProfileID,
            globalHotkeyChoice: globalHotkeyChoice,
            launchAtLogin: launchAtLogin
        )

        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }

    private func saveBookmarks() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: bookmarksKey)
        }
    }

    private func saveSearchHistory() {
        if let data = try? JSONEncoder().encode(searchHistory) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    private func saveUserFilters() {
        if let data = try? JSONEncoder().encode(userFilters) {
            UserDefaults.standard.set(data, forKey: userFiltersKey)
        }
    }

    private func scheduleHistoryRecording(for value: String) {
        historyTask?.cancel()
        let capturedQuery = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !capturedQuery.isEmpty else {
            return
        }

        historyTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard let self, !Task.isCancelled else {
                return
            }
            if self.query.trimmingCharacters(in: .whitespacesAndNewlines) == capturedQuery {
                self.recordSearchHistory(capturedQuery)
            }
        }
    }

    private func recordSearchHistory(_ rawQuery: String) {
        let trimmedQuery = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return
        }

        if let index = searchHistory.firstIndex(where: { $0.query == trimmedQuery }) {
            searchHistory[index].lastUsedAt = Date()
            searchHistory[index].useCount += 1
            let item = searchHistory.remove(at: index)
            searchHistory.insert(item, at: 0)
        } else {
            searchHistory.insert(
                SearchHistoryItem(
                    id: UUID(),
                    query: trimmedQuery,
                    lastUsedAt: Date(),
                    useCount: 1
                ),
                at: 0
            )
        }

        trimSearchHistory()
        saveSearchHistory()
    }

    private func trimSearchHistory() {
        if searchHistory.count > 80 {
            searchHistory = Array(searchHistory.prefix(80))
        }
    }

    private func trimUserFilters() {
        if userFilters.count > 40 {
            userFilters = Array(userFilters.prefix(40))
        }
    }

    private func saveFileListSources() {
        guard let url = try? FileListSourceStorage.defaultURL() else {
            return
        }
        try? FileListSourceStorage.save(fileListSources, to: url)
    }

    private func saveIndexProfiles() {
        if let data = try? JSONEncoder().encode(indexProfiles) {
            UserDefaults.standard.set(data, forKey: profilesKey)
        }
    }

    private func refreshLaunchAtLoginState() {
        guard LaunchAtLoginController.isSupportedBundle else {
            return
        }
        launchAtLogin = LaunchAtLoginController.isEnabled
    }

    private func rebuildEntriesFromIndexes() {
        var combinedByPath: [String: FileEntry] = [:]

        for source in fileListSources where source.isEnabled {
            for entry in source.entriesWithSourceMetadata {
                combinedByPath[entry.path] = entry
            }
        }

        for profile in indexProfiles where profile.isEnabled && profile.id != activeProfileID {
            for entry in auxiliaryProfileEntriesByID[profile.id] ?? [] {
                combinedByPath[entry.path] = entry
            }
        }

        if activeIndexProfile?.isEnabled ?? true {
            for (path, entry) in fileIndex.snapshotByPath {
                combinedByPath[path] = entry
            }
        }

        entries = FileIndex(entries: Array(combinedByPath.values)).entries
    }

    private func loadAuxiliaryProfileIndex(_ profile: IndexProfile) {
        guard profile.isEnabled,
              profile.id != activeProfileID,
              let indexURL = try? IndexStorage.profileIndexURL(profileID: profile.id),
              FileManager.default.fileExists(atPath: indexURL.path),
              let snapshot = try? IndexStorage.load(from: indexURL) else {
            auxiliaryProfileEntriesByID.removeValue(forKey: profile.id)
            return
        }

        auxiliaryProfileEntriesByID[profile.id] = snapshot.entries
    }

    private func auxiliaryProfileID(containing path: String) -> String? {
        for (profileID, profileEntries) in auxiliaryProfileEntriesByID {
            if profileEntries.contains(where: { $0.path == path }) {
                return profileID
            }
        }
        return nil
    }

    private func updateAuxiliaryProfileEntry(_ updatedEntry: FileEntry, profileID: String) {
        guard var profileEntries = auxiliaryProfileEntriesByID[profileID],
              let entryIndex = profileEntries.firstIndex(where: { $0.path == updatedEntry.path }) else {
            return
        }

        profileEntries[entryIndex] = updatedEntry
        auxiliaryProfileEntriesByID[profileID] = profileEntries
    }

    private func entriesByPath(forProfileID profileID: String) -> [String: FileEntry] {
        if profileID == activeProfileID {
            return fileIndex.snapshotByPath
        }
        return FileIndex(entries: auxiliaryProfileEntriesByID[profileID] ?? []).snapshotByPath
    }

    private func replaceEntries(_ entries: [FileEntry], forProfileID profileID: String) {
        if profileID == activeProfileID {
            fileIndex.replaceAll(entries)
        } else {
            auxiliaryProfileEntriesByID[profileID] = entries
        }
    }

    private func reindexProfile(profileID: String) {
        guard let profile = indexProfiles.first(where: { $0.id == profileID }) else {
            return
        }

        loadIndexTask?.cancel()
        if profileID == activeProfileID {
            index(rootURL: URL(fileURLWithPath: profile.rootPath))
            return
        }

        let rootURL = URL(fileURLWithPath: profile.rootPath)
        let configuration = scanConfiguration(rootURL: rootURL, profile: profile)
        let existingEntriesByPath = entriesByPath(forProfileID: profileID)
        isIndexing = true
        statusText = "Indexing \(profile.displayName)..."
        updateQueryServiceState()

        indexTask = Task { [weak self] in
            let scannedEntries = await Task.detached(priority: .userInitiated) {
                FileScanner.scan(configuration: configuration, existingEntriesByPath: existingEntriesByPath)
            }.value

            guard let self, !Task.isCancelled else {
                return
            }

            self.replaceEntries(scannedEntries, forProfileID: profileID)
            self.rebuildEntriesFromIndexes()
            self.lastIndexedAt = Date()
            self.isIndexing = false
            self.statusText = "\(self.entries.count.formatted()) items\(self.enabledProfileCount > 1 ? " across \(self.enabledProfileCount) profiles" : "")"
            self.touchProfile(profileID: profileID, lastFSEventID: FileSystemMonitor.currentEventID())
            self.updateQueryServiceState()
            self.scheduleSearch()
            self.persistIndex(entries: scannedEntries, rootPath: profile.rootPath, profileID: profileID)
            self.startMonitoringEnabledProfiles()
        }
    }

    private func normalizeProfileEnabledState() {
        guard !indexProfiles.isEmpty,
              !indexProfiles.contains(where: \.isEnabled) else {
            return
        }

        let fallbackProfileID = activeProfileID ?? indexProfiles[0].id
        if let index = indexProfiles.firstIndex(where: { $0.id == fallbackProfileID }) {
            indexProfiles[index].isEnabled = true
        } else {
            indexProfiles[0].isEnabled = true
        }
    }

    private func ensureActiveProfile() {
        normalizeProfileEnabledState()

        if indexProfiles.isEmpty {
            indexProfiles = [IndexProfile.make(rootPath: rootPath)]
            activeProfileID = indexProfiles[0].id
            saveIndexProfiles()
            saveSettings()
            return
        }

        if let activeProfileID, indexProfiles.contains(where: { $0.id == activeProfileID }) {
            rootPath = indexProfiles.first { $0.id == activeProfileID }?.rootPath ?? rootPath
            return
        }

        activeProfileID = indexProfiles.first?.id
        rootPath = indexProfiles.first?.rootPath ?? rootPath
        saveSettings()
    }

    private func activateOrCreateProfile(rootPath: String, name: String) {
        let profile = IndexProfile.make(rootPath: rootPath, name: name)
        if !indexProfiles.contains(where: { $0.id == profile.id }) {
            indexProfiles.append(profile)
            indexProfiles.sort { lhs, rhs in
                lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
            saveIndexProfiles()
        } else if let index = indexProfiles.firstIndex(where: { $0.id == profile.id }),
                  !indexProfiles[index].isEnabled {
            indexProfiles[index].isEnabled = true
            indexProfiles[index].updatedAt = Date()
            saveIndexProfiles()
        }
        activeProfileID = profile.id
        self.rootPath = profile.rootPath
        saveSettings()
    }

    private func index(rootURL: URL) {
        loadIndexTask?.cancel()
        indexTask?.cancel()
        searchTask?.cancel()

        isIndexing = true
        statusText = "Indexing..."
        results = []
        totalMatches = 0
        selectedPath = nil
        updateQueryServiceState()

        let configuration = scanConfiguration(rootURL: rootURL)
        let existingEntriesByPath = fileIndex.snapshotByPath
        indexTask = Task { [weak self] in
            let scannedEntries = await Task.detached(priority: .userInitiated) {
                FileScanner.scan(configuration: configuration, existingEntriesByPath: existingEntriesByPath)
            }.value

            guard let self, !Task.isCancelled else {
                return
            }

            self.fileIndex.replaceAll(scannedEntries)
            self.rebuildEntriesFromIndexes()
            self.lastIndexedAt = Date()
            self.isIndexing = false
            self.statusText = "\(self.entries.count.formatted()) items\(self.enabledProfileCount > 1 ? " across \(self.enabledProfileCount) profiles" : "")"
            self.touchActiveProfile(lastFSEventID: FileSystemMonitor.currentEventID())
            self.saveSettings()
            self.updateQueryServiceState()
            self.scheduleSearch()
            self.persistIndex(entries: scannedEntries, rootPath: rootURL.path)
            self.startMonitoringEnabledProfiles()
        }
    }

    private func startMonitoringEnabledProfiles() {
        let enabledProfileIDs = Set(indexProfiles.filter(\.isEnabled).map(\.id))

        let staleProfileIDs = fileSystemMonitorsByProfileID.keys.filter { !enabledProfileIDs.contains($0) }
        for profileID in staleProfileIDs {
            fileSystemMonitorsByProfileID[profileID]?.stop()
            fileSystemMonitorsByProfileID.removeValue(forKey: profileID)
            monitorReindexTasksByProfileID[profileID]?.cancel()
            monitorReindexTasksByProfileID.removeValue(forKey: profileID)
            pendingFileSystemChangesByProfileID.removeValue(forKey: profileID)
        }

        for profile in indexProfiles where profile.isEnabled {
            startMonitoring(profile: profile)
        }
    }

    private func startMonitoring(profile: IndexProfile) {
        fileSystemMonitorsByProfileID[profile.id]?.stop()

        let monitor = FileSystemMonitor(
            rootURL: URL(fileURLWithPath: profile.rootPath),
            excludedPathPrefixes: effectiveExcludedPathPrefixes(for: profile),
            sinceEventID: nil,
            onChange: { [weak self, profileID = profile.id] changes, latestEventID in
                Task { @MainActor in
                    self?.handleFileSystemChanges(
                        profileID: profileID,
                        changes: changes,
                        latestEventID: latestEventID
                    )
                }
            }
        )
        fileSystemMonitorsByProfileID[profile.id] = monitor
        monitor.start()
    }

    private func startQueryService() {
        guard queryHTTPServer == nil else {
            return
        }

        do {
            queryHTTPServer = try QueryHTTPServer(
                port: 16245,
                searchHandler: { [queryServiceState] request in
                    queryServiceState.search(request: request)
                },
                statusHandler: { [queryServiceState] in
                    queryServiceState.status()
                }
            )
        } catch {
            statusText = "Query service unavailable"
        }
    }

    private func startGlobalHotkey() {
        guard globalHotkeyController == nil else {
            return
        }

        let controller = GlobalHotkeyController { [weak self] in
            self?.showCompactSearch()
        }
        if !controller.register(globalHotkeyChoice) {
            statusText = "Hotkey unavailable"
        }
        globalHotkeyController = controller
    }

    private func handleFileSystemChanges(
        profileID: String,
        changes: [FileSystemChange],
        latestEventID: UInt64?
    ) {
        updateProfileFSEventID(profileID: profileID, eventID: latestEventID)

        guard !changes.isEmpty else {
            return
        }

        var pendingChanges = pendingFileSystemChangesByProfileID[profileID] ?? [:]
        for change in changes {
            if let existing = pendingChanges[change.path] {
                pendingChanges[change.path] = existing.merging(change)
            } else {
                pendingChanges[change.path] = change
            }
        }
        pendingFileSystemChangesByProfileID[profileID] = pendingChanges

        monitorReindexTasksByProfileID[profileID]?.cancel()

        monitorReindexTasksByProfileID[profileID] = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard let self, !Task.isCancelled else {
                return
            }
            if self.isIndexing && profileID == self.activeProfileID {
                return
            }
            let pendingChanges = self.pendingFileSystemChangesByProfileID[profileID] ?? [:]
            let changes = Array(pendingChanges.values)
            self.pendingFileSystemChangesByProfileID.removeValue(forKey: profileID)
            self.monitorReindexTasksByProfileID.removeValue(forKey: profileID)
            self.applyFileSystemChanges(changes: changes, profileID: profileID)
        }
    }

    private func applyFileSystemChanges(changes: [FileSystemChange], profileID: String) {
        guard let profile = indexProfiles.first(where: { $0.id == profileID }) else {
            return
        }

        let rootPath = profile.rootPath
        let normalizedPaths = normalizedChangedPaths(for: changes).sorted { lhs, rhs in
            lhs.count < rhs.count
        }

        if normalizedPaths.isEmpty {
            return
        }

        if changes.contains(where: \.requiresFullScan) ||
            normalizedPaths.count > 128 ||
            normalizedPaths.contains(where: { $0 == rootPath }) {
            reindexProfile(profileID: profileID)
            return
        }

        let exclusionRules = profile.exclusionRules
        let runtimeExcludedPathPrefixes = self.runtimeExcludedPathPrefixes(forProfileID: profileID)
        let excludedPathPrefixes = effectiveExcludedPathPrefixes(for: profile)
        let existingEntriesByPath = entriesByPath(forProfileID: profileID)
        let existingEntriesByIdentity = Self.identityMap(for: existingEntriesByPath)
        var removedPaths: [String] = []
        var upsertedEntries: [FileEntry] = []
        var profileIndex = FileIndex(entries: Array(existingEntriesByPath.values))

        for path in normalizedPaths {
            if Self.isPathExcluded(path, by: excludedPathPrefixes) {
                continue
            }

            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)

            if exists {
                removedPaths.append(contentsOf: profileIndex.remove(path: path))
                let scannedEntries = FileScanner.scanChangedPath(
                    path: path,
                    existingEntriesByPath: existingEntriesByPath,
                    exclusionRules: exclusionRules,
                    runtimeExcludedPathPrefixes: runtimeExcludedPathPrefixes
                )
                let restoredEntries = scannedEntries.map { entry in
                    Self.restoringRunState(
                        for: entry,
                        existingEntriesByPath: existingEntriesByPath,
                        existingEntriesByIdentity: existingEntriesByIdentity
                    )
                }
                profileIndex.upsert(restoredEntries)
                upsertedEntries.append(contentsOf: restoredEntries)
            } else {
                removedPaths.append(contentsOf: profileIndex.remove(path: path))
            }
        }

        guard !removedPaths.isEmpty || !upsertedEntries.isEmpty else {
            statusText = "\(entries.count.formatted()) items\(enabledProfileCount > 1 ? " across \(enabledProfileCount) profiles" : "")"
            updateQueryServiceState()
            return
        }

        replaceEntries(profileIndex.entries, forProfileID: profileID)
        rebuildEntriesFromIndexes()
        lastIndexedAt = Date()
        statusText = "\(entries.count.formatted()) items\(enabledProfileCount > 1 ? " across \(enabledProfileCount) profiles" : "")"
        updateQueryServiceState()
        scheduleSearch()
        persistIncremental(
            upsertedEntries: upsertedEntries,
            removedPaths: removedPaths,
            profileID: profileID,
            rootPath: rootPath
        )
    }

    private nonisolated static func identityMap(
        for entriesByPath: [String: FileEntry]
    ) -> [String: FileEntry] {
        var entriesByIdentity: [String: FileEntry] = [:]
        for entry in entriesByPath.values {
            guard let identityKey = entry.identityKey else {
                continue
            }
            entriesByIdentity[identityKey] = entry
        }
        return entriesByIdentity
    }

    private nonisolated static func restoringRunState(
        for entry: FileEntry,
        existingEntriesByPath: [String: FileEntry],
        existingEntriesByIdentity: [String: FileEntry]
    ) -> FileEntry {
        if existingEntriesByPath[entry.path] != nil {
            return entry
        }

        guard let identityKey = entry.identityKey,
              let previousEntry = existingEntriesByIdentity[identityKey] else {
            return entry
        }

        return entry.preservingRunState(from: previousEntry)
    }

    private func normalizedChangedPaths(for changes: [FileSystemChange]) -> [String] {
        var paths = Set<String>()
        for change in changes {
            paths.insert(change.path)

            if change.shouldScanParent {
                let parent = URL(fileURLWithPath: change.path).deletingLastPathComponent().path
                paths.insert(parent)
            }
        }
        return Array(paths)
    }

    private func persistIndex(entries: [FileEntry], rootPath: String) {
        guard let activeProfileID else {
            return
        }
        persistIndex(entries: entries, rootPath: rootPath, profileID: activeProfileID)
    }

    private func persistIndex(entries: [FileEntry], rootPath: String, profileID: String) {
        guard let indexURL = try? IndexStorage.profileIndexURL(profileID: profileID) else {
            return
        }

        let snapshot = IndexSnapshot(rootPath: rootPath, entries: entries)
        Task.detached(priority: .utility) {
            try? IndexStorage.save(snapshot, to: indexURL)
        }
    }

    private func persistIncremental(upsertedEntries: [FileEntry], removedPaths: [String]) {
        guard let indexURL = activeIndexURL else {
            return
        }

        let rootPath = rootPath
        Task.detached(priority: .utility) {
            try? IndexStorage.delete(paths: removedPaths, rootPath: rootPath, from: indexURL)
            try? IndexStorage.upsert(entries: upsertedEntries, rootPath: rootPath, to: indexURL)
        }
    }

    private func persistIncremental(
        upsertedEntries: [FileEntry],
        removedPaths: [String],
        profileID: String,
        rootPath: String
    ) {
        guard let indexURL = try? IndexStorage.profileIndexURL(profileID: profileID) else {
            return
        }

        Task.detached(priority: .utility) {
            try? IndexStorage.delete(paths: removedPaths, rootPath: rootPath, from: indexURL)
            try? IndexStorage.upsert(entries: upsertedEntries, rootPath: rootPath, to: indexURL)
        }
    }

    private func recordRun(for entry: FileEntry) {
        let updatedEntry = entry.recordingRun()

        func replace(_ candidate: FileEntry) -> FileEntry {
            candidate.path == entry.path ? updatedEntry : candidate
        }

        let didUpdateLocalIndex: Bool
        if activeIndexProfile?.isEnabled != false,
           fileIndex.entry(path: entry.path) != nil {
            fileIndex.upsert(updatedEntry)
            didUpdateLocalIndex = true
        } else if updateFileListEntry(updatedEntry) {
            saveFileListSources()
            didUpdateLocalIndex = false
        } else if let profileID = auxiliaryProfileID(containing: entry.path) {
            updateAuxiliaryProfileEntry(updatedEntry, profileID: profileID)
            persistIncremental(
                upsertedEntries: [updatedEntry],
                removedPaths: [],
                profileID: profileID,
                rootPath: indexProfiles.first { $0.id == profileID }?.rootPath ?? updatedEntry.parent
            )
            didUpdateLocalIndex = false
        } else {
            fileIndex.upsert(updatedEntry)
            didUpdateLocalIndex = true
        }

        rebuildEntriesFromIndexes()
        results = results.map(replace)
        updateQueryServiceState()
        if didUpdateLocalIndex {
            persistIncremental(upsertedEntries: [updatedEntry], removedPaths: [entry.path])
        }

        if sortField == .runCount || sortField == .dateRun || sortField == .relevance {
            scheduleSearch()
        }
    }

    private func updateFileListEntry(_ updatedEntry: FileEntry) -> Bool {
        for sourceIndex in fileListSources.indices {
            guard let entryIndex = fileListSources[sourceIndex].entries.firstIndex(where: { $0.path == updatedEntry.path }) else {
                continue
            }
            fileListSources[sourceIndex].entries[entryIndex] = updatedEntry
            fileListSources[sourceIndex].updatedAt = Date()
            return true
        }
        return false
    }

    private func scheduleSearch() {
        searchTask?.cancel()

        let query = query
        let entries = entries
        let activeFilter = activeFilter
        let sortField = sortField
        let sortDirection = sortDirection
        let searchOptions = searchOptions
        let indexURLs = enabledProfileIndexURLs
        let activeFileListEntries = fileListSources
            .filter(\.isEnabled)
            .flatMap(\.entriesWithSourceMetadata)
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(120))

            let worker = Task.detached(priority: .userInitiated) {
                let effectiveQuery = Self.effectiveQuery(userQuery: query, filter: activeFilter)
                let request = SearchRequest(
                    query: effectiveQuery,
                    sortField: sortField,
                    sortDirection: sortDirection,
                    options: searchOptions
                )

                if let databaseResponse = Self.databaseBackedSearch(
                    request: request,
                    entries: entries,
                    indexURLs: indexURLs,
                    activeFileListEntries: activeFileListEntries
                ) {
                    return databaseResponse
                }

                return SearchEngine.search(
                    request: request,
                    in: entries,
                    shouldCancel: { Task.isCancelled }
                )
            }
            let response = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }

            guard let self, !Task.isCancelled else {
                return
            }

            self.results = response.entries
            self.totalMatches = response.totalMatches
            self.searchWarnings = response.warnings
            self.updateQueryServiceState()
            if let selectedPath = self.selectedPath, !response.entries.contains(where: { $0.path == selectedPath }) {
                self.selectedPath = nil
            }
        }
    }

    private nonisolated static func mergeCandidateEntries(
        _ lhs: [FileEntry],
        _ rhs: [FileEntry]
    ) -> [FileEntry] {
        guard !rhs.isEmpty else {
            return lhs
        }

        var entriesByPath: [String: FileEntry] = [:]
        entriesByPath.reserveCapacity(lhs.count + rhs.count)

        for entry in rhs {
            entriesByPath[entry.path] = entry
        }

        for entry in lhs {
            entriesByPath[entry.path] = entry
        }

        return Array(entriesByPath.values)
    }

    private func updateQueryServiceState() {
        queryServiceState.update(
            rootPath: rootPath,
            entries: entries,
            indexURLs: enabledProfileIndexURLs,
            fileListEntries: fileListSources
                .filter(\.isEnabled)
                .flatMap(\.entriesWithSourceMetadata),
            resultCount: results.count,
            lastIndexedAt: lastIndexedAt,
            statusText: statusText,
            isIndexing: isIndexing,
            sortField: sortField,
            sortDirection: sortDirection,
            options: searchOptions
        )
    }

    private nonisolated static func effectiveQuery(userQuery: String, filter: ResultFilter) -> String {
        let trimmedUserQuery = userQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let filterPrefix = filter.searchPrefix
        if filterPrefix.isEmpty {
            return trimmedUserQuery
        }
        if trimmedUserQuery.isEmpty {
            return filterPrefix
        }
        return "\(filterPrefix) \(trimmedUserQuery)"
    }

    fileprivate nonisolated static func databaseBackedSearch(
        request: SearchRequest,
        entries: [FileEntry],
        indexURLs: [URL],
        activeFileListEntries: [FileEntry]
    ) -> SearchResponse? {
        guard entries.count > 25_000 else {
            return nil
        }

        if activeFileListEntries.isEmpty,
           let windowEntries = try? databaseWindowEntries(
            request: request,
            indexURLs: indexURLs
           ),
           !windowEntries.isEmpty {
            let windowResponse = SearchEngine.searchCandidateSubset(request: request, in: windowEntries)
            return SearchResponse(
                entries: windowResponse.entries,
                totalMatches: entries.count,
                warnings: windowResponse.warnings
            )
        }

        if let candidateEntries = try? databaseCandidateEntries(
            request: request,
            indexURLs: indexURLs
        ) {
            return SearchEngine.searchCandidateSubset(
                request: request,
                in: mergeCandidateEntries(candidateEntries, activeFileListEntries)
            )
        }

        return nil
    }

    private nonisolated static func databaseCandidateEntries(
        request: SearchRequest,
        indexURLs: [URL]
    ) throws -> [FileEntry]? {
        guard !indexURLs.isEmpty else {
            return nil
        }

        let hint = SearchEngine.candidateHint(for: request)
        guard hint.canUseDatabaseCandidates else {
            return nil
        }

        var candidatesByPath: [String: FileEntry] = [:]
        let requestedWindowEnd = max(request.offset + request.limit, request.limit)
        let shortestTermLength = hint.terms.map(\.count).min() ?? Int.max
        let candidateMultiplier = shortestTermLength <= 2 ? 8 : 16
        let candidateFloor = shortestTermLength <= 2 ? 1_000 : 2_000
        let candidateCeiling = shortestTermLength <= 2 ? 5_000 : 12_000
        let perIndexLimit = min(
            max(requestedWindowEnd * candidateMultiplier, candidateFloor),
            candidateCeiling
        )
        for indexURL in indexURLs {
            let candidates = try IndexStorage.candidateEntries(
                hint: hint,
                limit: perIndexLimit,
                from: indexURL
            )
            for candidate in candidates {
                candidatesByPath[candidate.path] = candidate
            }
        }

        return Array(candidatesByPath.values)
    }

    private nonisolated static func databaseWindowEntries(
        request: SearchRequest,
        indexURLs: [URL]
    ) throws -> [FileEntry]? {
        guard !indexURLs.isEmpty,
              request.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              request.offset == 0,
              request.sortField == .relevance ||
                (request.sortField == .dateModified && request.sortDirection == .descending) else {
            return nil
        }

        var candidatesByPath: [String: FileEntry] = [:]
        for indexURL in indexURLs {
            let candidates = try IndexStorage.windowEntries(
                limit: request.limit,
                offset: request.offset,
                from: indexURL
            )
            for candidate in candidates {
                candidatesByPath[candidate.path] = candidate
            }
        }

        return Array(candidatesByPath.values)
    }

    private func addExcludedPaths(_ paths: [String]) {
        let normalizedPaths = paths.compactMap(normalizedExclusionPath)
        guard !normalizedPaths.isEmpty else {
            statusText = "No eligible paths selected"
            return
        }

        updateActiveProfileExclusionRules(status: "Path excluded") { rules in
            rules.excludedPathPrefixes.append(contentsOf: normalizedPaths)
        }
    }

    private func normalizedExclusionPath(_ path: String) -> String? {
        guard let normalizedPath = IndexExclusionRules.normalizedPathPrefix(for: path) else {
            return nil
        }
        let normalizedRootPath = URL(fileURLWithPath: rootPath)
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
        guard normalizedPath != normalizedRootPath else {
            statusText = "Cannot exclude active root"
            return nil
        }
        let isInsideRoot = normalizedRootPath == "/" ?
            normalizedPath.hasPrefix("/") :
            normalizedPath.hasPrefix(normalizedRootPath + "/")
        guard isInsideRoot else {
            statusText = "Excluded path must be inside active root"
            return nil
        }
        return normalizedPath
    }

    private func updateActiveProfileExclusionRules(
        status: String,
        update: (inout IndexExclusionRules) -> Void
    ) {
        guard let activeProfileID,
              let index = indexProfiles.firstIndex(where: { $0.id == activeProfileID }) else {
            statusText = "No active profile"
            return
        }

        var rules = indexProfiles[index].exclusionRules
        let originalRules = rules
        update(&rules)
        rules = rules.normalized()

        guard rules != originalRules else {
            statusText = "Exclusions unchanged"
            return
        }

        indexProfiles[index].exclusionRules = rules
        indexProfiles[index].updatedAt = Date()
        saveIndexProfiles()
        statusText = status
        reindexCurrentRoot()
    }

    private func touchActiveProfile(lastFSEventID: UInt64? = nil) {
        guard let activeProfileID else {
            return
        }
        touchProfile(profileID: activeProfileID, lastFSEventID: lastFSEventID)
    }

    private func touchProfile(profileID: String, lastFSEventID: UInt64? = nil) {
        guard let index = indexProfiles.firstIndex(where: { $0.id == profileID }) else {
            return
        }

        if profileID == activeProfileID {
            indexProfiles[index].rootPath = rootPath
        }
        indexProfiles[index].updatedAt = Date()
        if let lastFSEventID {
            indexProfiles[index].lastFSEventID = lastFSEventID
        }
        saveIndexProfiles()
    }

    private func updateProfileFSEventID(profileID: String, eventID: UInt64?) {
        guard let eventID,
              let index = indexProfiles.firstIndex(where: { $0.id == profileID }),
              (indexProfiles[index].lastFSEventID ?? 0) < eventID else {
            return
        }

        indexProfiles[index].lastFSEventID = eventID
        saveIndexProfiles()
    }

    private nonisolated static func isPathExcluded(_ path: String, by prefixes: [String]) -> Bool {
        let resolvedPath = URL(fileURLWithPath: path)
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
        return prefixes.contains { prefix in
            path == prefix ||
                path.hasPrefix(prefix + "/") ||
                resolvedPath == prefix ||
                resolvedPath.hasPrefix(prefix + "/")
        }
    }

    private nonisolated static func defaultDirection(for field: SearchSortField) -> SearchSortDirection {
        switch field {
        case .relevance, .name, .path, .extensionName, .kind, .attributes,
             .title, .artist, .album, .comment, .genre:
            return .ascending
        case .size, .dateModified, .dateCreated, .dateAccessed, .dateIndexed, .runCount, .dateRun,
             .track, .year:
            return .descending
        }
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
