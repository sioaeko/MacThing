import AppKit
import MacThingCore
import SwiftUI

@main
struct MacThingApp: App {
    @Environment(\.openSettings) private var openSettings
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
                .appKeyboardShortcut(store.appShortcutSettings.choice(for: .quickSearch))

                Button("Show Window") {
                    store.showMainWindow()
                }
                .appKeyboardShortcut(store.appShortcutSettings.choice(for: .showWindow))

                Button("Reindex") {
                    store.reindexCurrentRoot()
                }
                .appKeyboardShortcut(store.appShortcutSettings.choice(for: .reindex))

                Button("Toggle Path Match") {
                    store.toggleMatchPath()
                }
                .appKeyboardShortcut(store.appShortcutSettings.choice(for: .toggleMatchPath))

                Button("Toggle Fuzzy Matching") {
                    store.toggleFuzzyMatching()
                }
                .appKeyboardShortcut(store.appShortcutSettings.choice(for: .toggleFuzzyMatching))

                Button("Toggle Case Sensitive") {
                    store.toggleCaseSensitive()
                }
                .appKeyboardShortcut(store.appShortcutSettings.choice(for: .toggleCaseSensitive))

                Button("Toggle Regex Matching") {
                    store.toggleRegexMatching()
                }
                .appKeyboardShortcut(store.appShortcutSettings.choice(for: .toggleRegexMatching))

                Button("Toggle Whole Word") {
                    store.toggleWholeWordMatching()
                }
                .appKeyboardShortcut(store.appShortcutSettings.choice(for: .toggleWholeWordMatching))

                Button("Toggle Diacritics") {
                    store.toggleDiacriticSensitive()
                }
                .appKeyboardShortcut(store.appShortcutSettings.choice(for: .toggleDiacriticSensitive))

                Button("Export Visible Results") {
                    store.exportVisibleResults()
                }
                .disabled(store.results.isEmpty)
                .appKeyboardShortcut(store.appShortcutSettings.choice(for: .exportVisibleResults))
            }
        }

        Settings {
            SettingsView()
                .environmentObject(store)
        }

        MenuBarExtra("MacThing", systemImage: "magnifyingglass") {
            Button("Quick Search") {
                store.showCompactSearch()
            }

            Button("Show Window") {
                store.showMainWindow()
            }

            Divider()

            Button("Settings") {
                openSettings()
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

            Menu("Shortcuts") {
                AppShortcutMenuContent()
                    .environmentObject(store)
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

private extension View {
    @ViewBuilder
    func appKeyboardShortcut(_ choice: AppShortcutChoice) -> some View {
        if let keyEquivalent = choice.keyEquivalent {
            keyboardShortcut(keyEquivalent, modifiers: choice.eventModifiers)
        } else {
            self
        }
    }
}

private extension AppShortcutChoice {
    var keyEquivalent: KeyEquivalent? {
        guard let key else {
            return nil
        }

        switch key {
        case .returnKey:
            return .return
        case .tab:
            return .tab
        case .delete:
            return .delete
        case .escape:
            return .escape
        case .home:
            return .home
        case .pageUp:
            return .pageUp
        case .forwardDelete:
            return .deleteForward
        case .end:
            return .end
        case .pageDown:
            return .pageDown
        case .leftArrow:
            return .leftArrow
        case .rightArrow:
            return .rightArrow
        case .downArrow:
            return .downArrow
        case .upArrow:
            return .upArrow
        default:
            guard let literal = key.keyEquivalentLiteral,
                  let character = literal.first else {
                return nil
            }
            return KeyEquivalent(character)
        }
    }

    var eventModifiers: EventModifiers {
        var eventModifiers: EventModifiers = []
        if modifiers.contains(.command) {
            eventModifiers.insert(.command)
        }
        if modifiers.contains(.control) {
            eventModifiers.insert(.control)
        }
        if modifiers.contains(.option) {
            eventModifiers.insert(.option)
        }
        if modifiers.contains(.shift) {
            eventModifiers.insert(.shift)
        }
        return eventModifiers
    }
}
