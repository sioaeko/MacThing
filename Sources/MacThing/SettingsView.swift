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
        .frame(width: 760, height: 620)
    }
}

private struct ShortcutSettingsPane: View {
    @EnvironmentObject private var store: SearchStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 12) {
                    Label("Key Mapping", systemImage: "keyboard")
                        .font(.title3.weight(.semibold))

                    Spacer()

                    Button {
                        store.resetShortcutSettings()
                    } label: {
                        Label("Reset Defaults", systemImage: "arrow.counterclockwise")
                    }
                }

                GroupBox("Global Hotkey") {
                    ShortcutMappingHeader()

                    ShortcutMappingRow(
                        title: "Quick Search",
                        detail: "Open the floating search palette from anywhere",
                        value: store.globalHotkeyChoice.shortcut,
                        mode: .globalHotkey,
                        presets: GlobalHotkeyChoice.allCases.map(\.shortcut)
                    ) { choice in
                        store.setGlobalHotkeyChoice(GlobalHotkeyChoice(shortcut: choice))
                    }
                }

                ForEach(AppShortcutSection.allCases) { section in
                    GroupBox(section.rawValue) {
                        let actions = AppShortcutAction.allCases.filter { $0.settingsSection == section }

                        VStack(spacing: 0) {
                            ShortcutMappingHeader()

                            ForEach(actions.indices, id: \.self) { index in
                                let action = actions[index]

                                ShortcutMappingRow(
                                    title: action.displayName,
                                    detail: action.settingDetail,
                                    value: store.appShortcutSettings.choice(for: action),
                                    mode: .menuCommand,
                                    presets: action.availableChoices
                                ) { choice in
                                    store.setAppShortcutChoice(choice, for: action)
                                }

                                if index < actions.index(before: actions.endIndex) {
                                    Divider()
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }
}

private struct ShortcutMappingHeader: View {
    var body: some View {
        HStack(spacing: 16) {
            Text("Command")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Shortcut")
                .frame(width: 172, alignment: .leading)
            Text("Preset")
                .frame(width: 28, alignment: .center)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

private struct ShortcutMappingRow: View {
    let title: String
    let detail: String
    let value: AppShortcutChoice
    let mode: ShortcutRecorder.Mode
    let presets: [AppShortcutChoice]
    let onChange: (AppShortcutChoice) -> Void

    init(
        title: String,
        detail: String,
        value: AppShortcutChoice,
        mode: ShortcutRecorder.Mode,
        presets: [AppShortcutChoice],
        onChange: @escaping (AppShortcutChoice) -> Void
    ) {
        self.title = title
        self.detail = detail
        self.value = value
        self.mode = mode
        self.presets = presets
        self.onChange = onChange
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 16)

            ShortcutRecorder(value: value, mode: mode, onChange: onChange)
                .frame(width: 172, height: 28)

            Menu {
                ForEach(presets) { choice in
                    Button {
                        onChange(choice)
                    } label: {
                        if choice == value {
                            Label(choice.displayName, systemImage: "checkmark")
                        } else {
                            Text(choice.displayName)
                        }
                    }
                }

                if !presets.contains(.disabled) {
                    Divider()
                    Button("Disabled") {
                        onChange(.disabled)
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .frame(width: 20, height: 20)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)
            .help("Choose a preset shortcut")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
    }
}
