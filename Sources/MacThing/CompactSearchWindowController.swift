import AppKit
import MacThingCore
import SwiftUI

@MainActor
final class CompactSearchWindowController: NSObject, NSWindowDelegate {
    static let windowTitle = "MacThing Search"

    private weak var store: SearchStore?
    private var window: NSWindow?

    init(store: SearchStore) {
        self.store = store
        super.init()
    }

    func show() {
        guard let store else {
            return
        }

        let searchWindow = window ?? makeWindow(store: store)
        NSApp.activate()
        if !searchWindow.isVisible {
            searchWindow.center()
        }
        searchWindow.makeKeyAndOrderFront(nil)

        NotificationCenter.default.post(name: .compactSearchWindowDidShow, object: nil)
    }

    private func makeWindow(store: SearchStore) -> NSWindow {
        let rootView = CompactSearchView()
            .environmentObject(store)

        let searchWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        searchWindow.title = Self.windowTitle
        searchWindow.titleVisibility = .hidden
        searchWindow.titlebarAppearsTransparent = true
        searchWindow.isMovableByWindowBackground = true
        searchWindow.isReleasedWhenClosed = false
        searchWindow.level = .floating
        searchWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        searchWindow.contentView = NSHostingView(rootView: rootView)
        searchWindow.delegate = self
        window = searchWindow
        return searchWindow
    }
}

private struct CompactSearchView: View {
    @EnvironmentObject private var store: SearchStore
    @FocusState private var isSearchFocused: Bool

    private var visibleResults: ArraySlice<FileEntry> {
        store.results.prefix(8)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField(
                    "Search",
                    text: Binding(
                        get: { store.query },
                        set: { store.setQuery($0) }
                    )
                )
                .textFieldStyle(.plain)
                .font(.system(size: 22, weight: .regular))
                .focused($isSearchFocused)
                .onSubmit {
                    if !store.runSearchCommandIfNeeded() {
                        openSelectedOrFirst()
                    }
                }

                if !store.query.isEmpty {
                    Button {
                        store.setQuery("")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear")
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)

            Divider()

            ZStack {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(visibleResults) { entry in
                            CompactResultRow(
                                entry: entry,
                                isSelected: store.selectedPath == entry.path
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                store.selectedPath = entry.path
                            }
                            .onTapGesture(count: 2) {
                                open(entry: entry)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }

                if store.isIndexing {
                    ProgressView()
                        .controlSize(.large)
                } else if store.results.isEmpty {
                    Image(systemName: store.entries.isEmpty ? "folder.badge.questionmark" : "magnifyingglass")
                        .font(.system(size: 30))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 304)

            Divider()

            HStack(spacing: 10) {
                Text("\(store.totalMatches.formatted()) matches")
                    .lineLimit(1)

                Text(store.statusText)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Text(store.rootPath)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .font(.system(size: 12))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(width: 720, height: 420)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            focusSearchField()
            selectFirstResultIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .compactSearchWindowDidShow)) { _ in
            focusSearchField()
            selectFirstResultIfNeeded()
        }
        .onChange(of: store.results.map(\.path)) { _, paths in
            guard !paths.isEmpty else {
                store.selectedPath = nil
                return
            }
            if let selectedPath = store.selectedPath, paths.contains(selectedPath) {
                return
            }
            store.selectedPath = paths.first
        }
        .onMoveCommand { direction in
            switch direction {
            case .down:
                store.moveSelection(offset: 1)
            case .up:
                store.moveSelection(offset: -1)
            default:
                break
            }
        }
        .onExitCommand {
            NSApp.keyWindow?.orderOut(nil)
        }
    }

    private func focusSearchField() {
        DispatchQueue.main.async {
            isSearchFocused = true
        }
    }

    private func selectFirstResultIfNeeded() {
        guard let firstPath = store.results.first?.path else {
            return
        }
        if let selectedPath = store.selectedPath,
           store.results.contains(where: { $0.path == selectedPath }) {
            return
        }
        store.selectedPath = firstPath
    }

    private func openSelectedOrFirst() {
        store.openSelectedOrFirst()
        NSApp.keyWindow?.orderOut(nil)
    }

    private func open(entry: FileEntry) {
        store.selectedPath = entry.path
        store.openSelected()
        NSApp.keyWindow?.orderOut(nil)
    }
}

private struct CompactResultRow: View {
    let entry: FileEntry
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 11) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: entry.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .frame(width: 32, height: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(entry.parent)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 3) {
                Text(entry.kind.displayName)
                    .lineLimit(1)

                Text(entry.compactModifiedDescription)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .font(.system(size: 12))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            isSelected
                ? Color.accentColor.opacity(0.18)
                : Color.clear
        )
    }
}

private extension FileEntry {
    var compactModifiedDescription: String {
        guard let modifiedAt else {
            return "-"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: modifiedAt, relativeTo: Date())
    }
}

private extension Notification.Name {
    static let compactSearchWindowDidShow = Notification.Name("MacThing.CompactSearchWindowDidShow")
}
