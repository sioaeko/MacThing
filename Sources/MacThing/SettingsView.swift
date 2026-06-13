import MacThingCore
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            ShortcutSettingsPane()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
        }
        .frame(width: 520, height: 360)
    }
}

private struct ShortcutSettingsPane: View {
    @EnvironmentObject private var store: SearchStore

    var body: some View {
        Form {
            Section("Global") {
                Picker(
                    "Quick Search Hotkey",
                    selection: Binding(
                        get: { store.globalHotkeyChoice },
                        set: { store.setGlobalHotkeyChoice($0) }
                    )
                ) {
                    ForEach(GlobalHotkeyChoice.allCases) { choice in
                        Text(choice.displayName)
                            .tag(choice)
                    }
                }
            }

            Section("App Commands") {
                ForEach(AppShortcutAction.allCases) { action in
                    Picker(
                        action.displayName,
                        selection: Binding(
                            get: { store.appShortcutSettings.choice(for: action) },
                            set: { store.setAppShortcutChoice($0, for: action) }
                        )
                    ) {
                        ForEach(action.availableChoices) { choice in
                            Text(choice.displayName)
                                .tag(choice)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(18)
    }
}
