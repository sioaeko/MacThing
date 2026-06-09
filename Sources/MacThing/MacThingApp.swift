import AppKit
import SwiftUI

@main
struct MacThingApp: App {
    @StateObject private var store = SearchStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 900, minHeight: 620)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .appInfo) {
                Button("Quick Search") {
                    store.showCompactSearch()
                }
                .keyboardShortcut(" ", modifiers: [.option])

                Button("Reindex") {
                    store.reindexCurrentRoot()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra("MacThing", systemImage: "magnifyingglass") {
            Button("Quick Search") {
                store.showCompactSearch()
            }

            Button("Show Window") {
                store.showMainWindow()
            }

            Divider()

            Button("Reindex") {
                store.reindexCurrentRoot()
            }
            .disabled(store.isIndexing)

            if !store.searchHistory.isEmpty {
                Menu("History") {
                    ForEach(store.searchHistory.prefix(10)) { item in
                        Button(item.query) {
                            store.applyHistoryItem(item)
                            store.showCompactSearch()
                        }
                    }
                }
            }

            if !store.userFilters.isEmpty {
                Menu("Filters") {
                    ForEach(store.userFilters) { filter in
                        Button(filter.name) {
                            store.applyUserFilter(filter)
                            store.showCompactSearch()
                        }
                    }
                }
            }

            Menu("Hotkey: \(store.globalHotkeyChoice.displayName)") {
                ForEach(GlobalHotkeyChoice.allCases) { choice in
                    Button {
                        store.setGlobalHotkeyChoice(choice)
                    } label: {
                        if store.globalHotkeyChoice == choice {
                            Label(choice.displayName, systemImage: "checkmark")
                        } else {
                            Text(choice.displayName)
                        }
                    }
                }
            }

            Toggle(
                "Launch at Login",
                isOn: Binding(
                    get: { store.launchAtLogin },
                    set: { store.setLaunchAtLogin($0) }
                )
            )

            Text("\(store.entries.count.formatted()) indexed")

            if let lastIndexedAt = store.lastIndexedAt {
                Text(lastIndexedAt, style: .relative)
            }

            Divider()

            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
