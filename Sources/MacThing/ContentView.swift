import MacThingCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: SearchStore

    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            Divider()
            ResultHeader()
            Divider()
            ResultArea()
            Divider()
            StatusBar()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct TopBar: View {
    @EnvironmentObject private var store: SearchStore

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                SearchField(
                    text: Binding(
                        get: { store.query },
                        set: { store.setQuery($0) }
                    ),
                    onSubmit: {
                        if !store.runSearchCommandIfNeeded() {
                            store.openSelectedOrFirst()
                        }
                    }
                )
                .frame(minWidth: 420, maxWidth: .infinity)
                .layoutPriority(2)

                ToolbarCluster {
                    SearchHistoryMenu()
                    UserFiltersMenu()
                }

                ToolbarCluster {
                    Button {
                        store.chooseRoot()
                    } label: {
                        ToolbarIcon(systemName: "folder")
                    }
                    .help("Choose folder")

                    Button {
                        store.reindexCurrentRoot()
                    } label: {
                        ToolbarIcon(systemName: "arrow.clockwise")
                    }
                    .disabled(store.isIndexing)
                    .help("Reindex")

                    MoreMenu()
                }
            }

            HStack(spacing: 12) {
                FilterPicker()
                    .frame(minWidth: 520, idealWidth: 580, maxWidth: 660)
                    .layoutPriority(1)

                Spacer(minLength: 20)

                ToolbarCluster {
                    Button {
                        store.openSelected()
                    } label: {
                        ToolbarIcon(systemName: "arrow.up.forward.square")
                    }
                    .disabled(store.selectedEntry == nil)
                    .help("Open")

                    Button {
                        store.revealSelected()
                    } label: {
                        ToolbarIcon(systemName: "finder")
                    }
                    .disabled(store.selectedEntry == nil)
                    .help("Reveal in Finder")

                    Button {
                        store.copySelectedPath()
                    } label: {
                        ToolbarIcon(systemName: "doc.on.doc")
                    }
                    .disabled(store.selectedEntry == nil)
                    .help("Copy path")
                }

                ToolbarCluster {
                    SortMenu()
                    ToolbarGroupDivider()
                    MatchOptionButtons()
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private struct FilterPicker: View {
    @EnvironmentObject private var store: SearchStore

    var body: some View {
        Picker(
            "",
            selection: Binding(
                get: { store.activeFilter },
                set: { store.setFilter($0) }
            )
        ) {
            ForEach(ResultFilter.allCases) { filter in
                Text(filter.displayName)
                    .tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }
}

private struct SearchHistoryMenu: View {
    @EnvironmentObject private var store: SearchStore

    var body: some View {
        Menu {
            if store.searchHistory.isEmpty {
                Text("No History")
            } else {
                ForEach(store.searchHistory) { item in
                    Button {
                        store.applyHistoryItem(item)
                    } label: {
                        Text(item.query)
                    }
                }

                Divider()

                Menu("Remove") {
                    ForEach(store.searchHistory) { item in
                        Button(role: .destructive) {
                            store.removeHistoryItem(item)
                        } label: {
                            Text(item.query)
                        }
                    }
                }

                Button(role: .destructive) {
                    store.clearSearchHistory()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
            }
        } label: {
            ToolbarIcon(systemName: "clock.arrow.circlepath")
        }
        .help("Search history")
    }
}

private struct UserFiltersMenu: View {
    @EnvironmentObject private var store: SearchStore

    var body: some View {
        Menu {
            Button {
                store.addUserFilter()
            } label: {
                Label("Add Filter", systemImage: "line.3.horizontal.decrease.circle")
            }

            if !store.userFilters.isEmpty {
                Divider()

                ForEach(store.userFilters) { filter in
                    Button {
                        store.applyUserFilter(filter)
                    } label: {
                        Text(filter.name)
                    }
                }

                Divider()

                Menu("Remove") {
                    ForEach(store.userFilters) { filter in
                        Button(role: .destructive) {
                            store.removeUserFilter(filter)
                        } label: {
                            Text(filter.name)
                        }
                    }
                }
            }
        } label: {
            ToolbarIcon(systemName: "line.3.horizontal.decrease.circle")
        }
        .help("User filters")
    }
}

private struct MoreMenu: View {
    @EnvironmentObject private var store: SearchStore

    var body: some View {
        Menu {
            Menu("File Lists") {
                Button {
                    store.importFileList()
                } label: {
                    Label("Import", systemImage: "tray.and.arrow.down")
                }

                if !store.fileListSources.isEmpty {
                    Divider()

                    ForEach(store.fileListSources) { source in
                        Button {
                            store.toggleFileListSource(source)
                        } label: {
                            HStack {
                                Text("\(source.displayName) (\(source.itemCount.formatted()))")
                                if source.isEnabled {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }

                    Divider()

                    Menu("Refresh") {
                        ForEach(store.fileListSources) { source in
                            Button {
                                store.refreshFileListSource(source)
                            } label: {
                                Text(source.displayName)
                            }
                        }
                    }

                    Menu("Remove") {
                        ForEach(store.fileListSources) { source in
                            Button(role: .destructive) {
                                store.removeFileListSource(source)
                            } label: {
                                Text(source.displayName)
                            }
                        }
                    }
                }
            }

            Menu("Bookmarks") {
                Button {
                    store.addBookmark()
                } label: {
                    Label("Add Bookmark", systemImage: "bookmark")
                }

                if !store.bookmarks.isEmpty {
                    Divider()

                    ForEach(store.bookmarks) { bookmark in
                        Button {
                            store.applyBookmark(bookmark)
                        } label: {
                            Text(bookmark.name)
                        }
                    }

                    Divider()

                    Menu("Remove") {
                        ForEach(store.bookmarks) { bookmark in
                            Button(role: .destructive) {
                                store.removeBookmark(bookmark)
                            } label: {
                                Text(bookmark.name)
                            }
                        }
                    }
                }
            }

            Menu("Volumes") {
                Button {
                    store.refreshVolumes()
                } label: {
                    Label("Refresh Volumes", systemImage: "arrow.clockwise")
                }

                if !store.volumeProfiles.isEmpty {
                    Divider()

                    ForEach(store.volumeProfiles) { profile in
                        Button {
                            store.indexVolume(profile)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(profile.displayName)
                                    Text(profile.locationDescription)
                                        .foregroundStyle(.secondary)
                                }
                                Text(profile.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Menu("Index Profiles") {
                Button {
                    store.addProfileForCurrentRoot()
                } label: {
                    Label("Add Current Root", systemImage: "plus")
                }

                if !store.indexProfiles.isEmpty {
                    Divider()

                    ForEach(store.indexProfiles) { profile in
                        Button {
                            store.activateProfile(profile)
                        } label: {
                            Text(store.currentProfileLabel(profile))
                        }
                    }

                    Divider()

                    Menu("Search In") {
                        ForEach(store.indexProfiles) { profile in
                            Button {
                                store.toggleProfileSearch(profile)
                            } label: {
                                HStack {
                                    Text(profile.displayName)
                                    if profile.isEnabled {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }

                    Menu("Remove") {
                        ForEach(store.indexProfiles) { profile in
                            Button(role: .destructive) {
                                store.removeProfile(profile)
                            } label: {
                                Text(profile.displayName)
                            }
                        }
                    }
                }
            }

            Menu("Index Exclusions") {
                IndexExclusionMenuContent()
            }

            Menu("Columns") {
                ForEach(ResultColumn.allCases) { column in
                    Button {
                        store.toggleColumn(column)
                    } label: {
                        HStack {
                            Text(column.displayName)
                            if store.visibleColumns.contains(column) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Menu("Global Hotkey: \(store.globalHotkeyChoice.displayName)") {
                GlobalHotkeyMenuContent()
            }

            Menu("Diagnostics") {
                Button {
                    store.refreshPermissionDiagnostics()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button {
                    store.openFullDiskAccessSettings()
                } label: {
                    Label("Full Disk Access", systemImage: "lock.shield")
                }

                if !store.permissionIssues.isEmpty {
                    Divider()

                    ForEach(store.permissionIssues) { issue in
                        Text(issue.title)
                        Text(issue.detail)
                    }
                }
            }

            Divider()

            Button {
                store.exportVisibleResults()
            } label: {
                Label("Export Visible Results", systemImage: "square.and.arrow.up")
            }
            .disabled(store.results.isEmpty)
        } label: {
            ToolbarIcon(systemName: "ellipsis.circle")
        }
        .help("More")
    }
}

private struct SortMenu: View {
    @EnvironmentObject private var store: SearchStore

    var body: some View {
        Menu {
            ForEach(SearchSortField.allCases, id: \.self) { field in
                Button {
                    store.setSort(field)
                } label: {
                    HStack {
                        Text(field.displayName)
                        if store.sortField == field {
                            Image(systemName: store.sortDirection == .ascending ? "chevron.up" : "chevron.down")
                        }
                    }
                }
            }
        } label: {
            ToolbarIcon(systemName: "arrow.up.arrow.down")
        }
        .help("Sort by")
    }
}

private struct MatchOptionButtons: View {
    @EnvironmentObject private var store: SearchStore

    var body: some View {
        ToggleButton(
            iconName: "text.magnifyingglass",
            isOn: store.searchOptions.matchPath,
            action: store.toggleMatchPath
        )
        .help("Match path")

        ToggleButton(
            iconName: "sparkle.magnifyingglass",
            isOn: store.searchOptions.fuzzyMatching,
            action: store.toggleFuzzyMatching
        )
        .help("Fuzzy matching")

        ToggleButton(
            iconName: "textformat.size",
            isOn: store.searchOptions.caseSensitive,
            action: store.toggleCaseSensitive
        )
        .help("Case sensitive")

        ToggleButton(
            iconName: "chevron.left.forwardslash.chevron.right",
            isOn: store.searchOptions.regexMatching,
            action: store.toggleRegexMatching
        )
        .help("Regex")

        ToggleButton(
            iconName: "text.word.spacing",
            isOn: store.searchOptions.wholeWordMatching,
            action: store.toggleWholeWordMatching
        )
        .help("Match whole word")

        ToggleButton(
            iconName: "textformat.abc.dottedunderline",
            isOn: store.searchOptions.diacriticSensitive,
            action: store.toggleDiacriticSensitive
        )
        .help("Match diacritics")
    }
}

private struct ToolbarCluster<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    init(spacing: CGFloat = 4, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        HStack(spacing: spacing) {
            content
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color(nsColor: .separatorColor).opacity(0.75), lineWidth: 1)
        )
    }
}

private struct ToolbarIcon: View {
    let systemName: String
    var color: Color = .secondary

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(color)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
    }
}

private struct ToolbarGroupDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 2)
            .opacity(0.8)
    }
}

private struct IndexExclusionMenuContent: View {
    @EnvironmentObject private var store: SearchStore

    var body: some View {
        Button {
            store.chooseExcludedPaths()
        } label: {
            Label("Add Path", systemImage: "plus")
        }

        Button {
            store.excludeSelectedPath()
        } label: {
            Label("Exclude Selected Path", systemImage: "minus.circle")
        }
        .disabled(store.selectedEntry == nil)

        Button {
            store.excludeSelectedExtension()
        } label: {
            Label("Exclude Selected Extension", systemImage: "doc.badge.gearshape")
        }
        .disabled(store.selectedEntry?.extensionName.isEmpty != false)

        Button {
            store.addExcludedNamePattern()
        } label: {
            Label("Add Name Pattern", systemImage: "asterisk")
        }

        Divider()

        Button {
            store.toggleIndexHiddenFiles()
        } label: {
            Label(
                "Include Hidden Files",
                systemImage: store.activeIndexExclusionRules.includeHiddenFiles ? "checkmark" : "eye.slash"
            )
        }

        if !store.activeExcludedPathPrefixes.isEmpty {
            Divider()

            Menu("Paths") {
                ForEach(store.activeExcludedPathPrefixes, id: \.self) { path in
                    Button(role: .destructive) {
                        store.removeExcludedPath(path)
                    } label: {
                        Text(path)
                    }
                }
            }
        }

        if !store.activeExcludedNamePatterns.isEmpty {
            Menu("Name Patterns") {
                ForEach(store.activeExcludedNamePatterns, id: \.self) { pattern in
                    Button(role: .destructive) {
                        store.removeExcludedNamePattern(pattern)
                    } label: {
                        Text(pattern)
                    }
                }
            }
        }

        if !store.activeExcludedExtensions.isEmpty {
            Menu("Extensions") {
                ForEach(store.activeExcludedExtensions, id: \.self) { extensionName in
                    Button(role: .destructive) {
                        store.removeExcludedExtension(extensionName)
                    } label: {
                        Text(extensionName)
                    }
                }
            }
        }

        Divider()

        Button(role: .destructive) {
            store.clearIndexExclusions()
        } label: {
            Label("Clear Exclusions", systemImage: "trash")
        }
        .disabled(!store.activeIndexExclusionRules.hasCustomRules)
    }
}

private struct GlobalHotkeyMenuContent: View {
    @EnvironmentObject private var store: SearchStore

    var body: some View {
        ForEach(GlobalHotkeyChoice.allCases) { choice in
            Button {
                store.setGlobalHotkeyChoice(choice)
            } label: {
                HStack {
                    Text(choice.displayName)
                    if store.globalHotkeyChoice == choice {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
    }
}

private struct ToggleButton: View {
    let iconName: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ToolbarIcon(systemName: iconName, color: isOn ? .accentColor : .secondary)
        }
    }
}

private struct SearchField: View {
    @Binding var text: String
    var onSubmit: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .regular, design: .default))
                .onSubmit(onSubmit)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
}

private struct ResultHeader: View {
    @EnvironmentObject private var store: SearchStore

    var body: some View {
        HStack(spacing: 0) {
            ForEach(store.orderedVisibleColumns) { column in
                HeaderButton(title: column.displayName, field: column.sortField)
                    .resultColumnFrame(column)
            }
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct HeaderButton: View {
    @EnvironmentObject private var store: SearchStore

    let title: String
    let field: SearchSortField

    var body: some View {
        Button {
            store.setSort(field)
        } label: {
            HStack(spacing: 4) {
                Text(title)
                if store.sortField == field {
                    Image(systemName: store.sortDirection == .ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity, alignment: field == .size ? .trailing : .leading)
        }
        .buttonStyle(.plain)
    }
}

private struct ResultArea: View {
    @EnvironmentObject private var store: SearchStore

    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(store.results) { entry in
                        ResultRow(
                            entry: entry,
                            isSelected: store.selectedPath == entry.path
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.selectedPath = entry.path
                        }
                        .onTapGesture(count: 2) {
                            store.selectedPath = entry.path
                            store.openSelected()
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            if store.isIndexing {
                ProgressView()
                    .controlSize(.large)
            } else if store.entries.isEmpty {
                EmptyIndexView()
            } else if store.results.isEmpty {
                EmptyResultView()
            }
        }
    }
}

private struct ResultRow: View {
    @EnvironmentObject private var store: SearchStore

    let entry: FileEntry
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(store.orderedVisibleColumns) { column in
                ResultCell(entry: entry, column: column)
                    .resultColumnFrame(column)
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            isSelected
                ? Color.accentColor.opacity(0.18)
                : Color.clear
        )
    }
}

private struct ResultCell: View {
    let entry: FileEntry
    let column: ResultColumn

    var body: some View {
        Group {
            switch column {
            case .name:
                HStack(spacing: 10) {
                    FileIcon(path: entry.path)

                    Text(entry.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            case .path:
                Text(entry.parent)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            case .extensionName:
                Text(entry.extensionName)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            case .kind:
                Text(entry.kind.displayName)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            case .dateModified:
                Text(entry.modifiedDescription)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            case .size:
                Text(entry.sizeDescription)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            case .dateCreated:
                Text(entry.createdDescription)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            case .dateAccessed:
                Text(entry.accessedDescription)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            case .dateIndexed:
                Text(entry.indexedDescription)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            case .runCount:
                Text(entry.runCountValue.formatted())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            case .dateRun:
                Text(entry.lastRunDescription)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            case .attributes:
                Text(ResultExporter.attributeString(for: entry))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            case .title:
                Text(entry.mediaTitle ?? "")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            case .artist:
                Text(entry.mediaArtist ?? "")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            case .album:
                Text(entry.mediaAlbum ?? "")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            case .comment:
                Text(entry.mediaComment ?? "")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            case .genre:
                Text(entry.mediaGenre ?? "")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            case .track:
                Text(entry.mediaTrack.map(String.init) ?? "")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            case .year:
                Text(entry.mediaYear.map(String.init) ?? "")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func resultColumnFrame(_ column: ResultColumn) -> some View {
        switch column {
        case .name:
            frame(maxWidth: .infinity, alignment: .leading)
        case .path:
            frame(width: 320, alignment: .leading)
        case .extensionName:
            frame(width: 92, alignment: .leading)
        case .kind:
            frame(width: 84, alignment: .leading)
        case .dateModified, .dateCreated, .dateAccessed, .dateIndexed, .dateRun:
            frame(width: 136, alignment: .leading)
        case .size:
            frame(width: 96, alignment: .trailing)
        case .runCount:
            frame(width: 96, alignment: .trailing)
        case .attributes:
            frame(width: 92, alignment: .leading)
        case .title:
            frame(width: 180, alignment: .leading)
        case .artist, .album:
            frame(width: 156, alignment: .leading)
        case .comment:
            frame(width: 220, alignment: .leading)
        case .genre:
            frame(width: 120, alignment: .leading)
        case .track:
            frame(width: 76, alignment: .trailing)
        case .year:
            frame(width: 76, alignment: .trailing)
        }
    }
}

private struct FileIcon: View {
    let path: String

    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: path))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 22, height: 22)
            .frame(width: 30, height: 24, alignment: .leading)
    }
}

private struct EmptyIndexView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("No index")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct EmptyResultView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("No results")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct StatusBar: View {
    @EnvironmentObject private var store: SearchStore

    var body: some View {
        HStack(spacing: 12) {
            Text("\(store.results.count.formatted()) of \(store.totalMatches.formatted()) shown")
                .lineLimit(1)

            Text(store.statusText)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(store.rootPath)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if !store.searchWarnings.isEmpty {
                Text(store.searchWarnings.joined(separator: ", "))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }

            if !store.permissionIssues.isEmpty {
                Text(store.permissionIssues.first?.title ?? "Permissions")
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }

            Text(optionSummary)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let lastIndexedAt = store.lastIndexedAt {
                Text(lastIndexedAt, style: .relative)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 12))
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var optionSummary: String {
        var options: [String] = []
        if store.searchOptions.matchPath {
            options.append("Path")
        }
        if store.searchOptions.fuzzyMatching {
            options.append("Fuzzy")
        }
        if store.searchOptions.caseSensitive {
            options.append("Case")
        }
        if store.searchOptions.regexMatching {
            options.append("Regex")
        }
        if store.searchOptions.wholeWordMatching {
            options.append("Whole")
        }
        if store.searchOptions.diacriticSensitive {
            options.append("Diacritics")
        }
        options.append(store.sortField.displayName)
        return options.joined(separator: " | ")
    }
}

private extension FileEntry {
    var modifiedDescription: String {
        guard let modifiedAt else {
            return "-"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: modifiedAt, relativeTo: Date())
    }

    var sizeDescription: String {
        guard kind == .file, let byteSize else {
            return "-"
        }
        return ByteCountFormatter.string(fromByteCount: byteSize, countStyle: .file)
    }

    var createdDescription: String {
        relativeDescription(for: createdAt)
    }

    var accessedDescription: String {
        relativeDescription(for: accessedAt)
    }

    var indexedDescription: String {
        relativeDescription(for: indexedAt)
    }

    var lastRunDescription: String {
        relativeDescription(for: lastRunAt)
    }

    private func relativeDescription(for date: Date?) -> String {
        guard let date else {
            return "-"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
