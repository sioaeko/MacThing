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
    @State private var shortcutSearchText = ""

    var body: some View {
        let query = shortcutSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedQuery = query.lowercased()
        let showsGlobalHotkey = shortcutRowMatches(
            title: "Quick Search",
            detail: "Open the floating search palette from anywhere",
            value: store.globalHotkeyChoice.shortcut,
            defaultValue: GlobalHotkeyChoice.recommended.shortcut,
            normalizedQuery: normalizedQuery
        )

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

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Filter commands or shortcuts", text: $shortcutSearchText)
                        .textFieldStyle(.plain)

                    if !shortcutSearchText.isEmpty {
                        Button {
                            shortcutSearchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Clear filter")
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color(nsColor: .controlBackgroundColor))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                }

                if showsGlobalHotkey {
                    GroupBox("Global Hotkey") {
                        ShortcutMappingHeader()

                        ShortcutMappingRow(
                            title: "Quick Search",
                            detail: "Open the floating search palette from anywhere",
                            value: store.globalHotkeyChoice.shortcut,
                            defaultValue: GlobalHotkeyChoice.recommended.shortcut,
                            mode: .globalHotkey,
                            presets: GlobalHotkeyChoice.allCases.map(\.shortcut)
                        ) { choice in
                            store.setGlobalHotkeyChoice(GlobalHotkeyChoice(shortcut: choice))
                        } onReset: {
                            store.setGlobalHotkeyChoice(GlobalHotkeyChoice.recommended)
                        }
                    }
                }

                ForEach(AppShortcutSection.allCases) { section in
                    let actions = filteredActions(in: section, normalizedQuery: normalizedQuery)

                    if !actions.isEmpty {
                        GroupBox(section.rawValue) {
                            VStack(spacing: 0) {
                                ShortcutMappingHeader()

                                ForEach(actions.indices, id: \.self) { index in
                                    let action = actions[index]

                                    ShortcutMappingRow(
                                        title: action.displayName,
                                        detail: action.settingDetail,
                                        value: store.appShortcutSettings.choice(for: action),
                                        defaultValue: action.defaultChoice,
                                        mode: .menuCommand,
                                        presets: action.availableChoices
                                    ) { choice in
                                        store.setAppShortcutChoice(choice, for: action)
                                    } onReset: {
                                        store.resetAppShortcutChoice(for: action)
                                    }

                                    if index < actions.index(before: actions.endIndex) {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                }

                if !query.isEmpty && !showsGlobalHotkey && filteredActionCount(normalizedQuery: normalizedQuery) == 0 {
                    ContentUnavailableView.search(text: query)
                        .frame(maxWidth: .infinity, minHeight: 180)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }

    private func filteredActions(
        in section: AppShortcutSection,
        normalizedQuery: String
    ) -> [AppShortcutAction] {
        AppShortcutAction.allCases.filter { action in
            action.settingsSection == section &&
                shortcutRowMatches(
                    title: action.displayName,
                    detail: action.settingDetail,
                    value: store.appShortcutSettings.choice(for: action),
                    defaultValue: action.defaultChoice,
                    normalizedQuery: normalizedQuery
                )
        }
    }

    private func filteredActionCount(normalizedQuery: String) -> Int {
        AppShortcutAction.allCases.filter { action in
            shortcutRowMatches(
                title: action.displayName,
                detail: action.settingDetail,
                value: store.appShortcutSettings.choice(for: action),
                defaultValue: action.defaultChoice,
                normalizedQuery: normalizedQuery
            )
        }.count
    }

    private func shortcutRowMatches(
        title: String,
        detail: String,
        value: AppShortcutChoice,
        defaultValue: AppShortcutChoice,
        normalizedQuery: String
    ) -> Bool {
        guard !normalizedQuery.isEmpty else {
            return true
        }

        return [
            title,
            detail,
            value.displayName,
            defaultValue.displayName
        ].contains { text in
            text.lowercased().contains(normalizedQuery)
        }
    }
}

private struct ShortcutMappingHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("Command")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Default")
                .frame(width: 128, alignment: .leading)
            Text("Shortcut")
                .frame(width: 172, alignment: .leading)
            Text("Preset")
                .frame(width: 28, alignment: .center)
            Text("Reset")
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
    let defaultValue: AppShortcutChoice
    let mode: ShortcutRecorder.Mode
    let presets: [AppShortcutChoice]
    let onChange: (AppShortcutChoice) -> Void
    let onReset: () -> Void

    init(
        title: String,
        detail: String,
        value: AppShortcutChoice,
        defaultValue: AppShortcutChoice,
        mode: ShortcutRecorder.Mode,
        presets: [AppShortcutChoice],
        onChange: @escaping (AppShortcutChoice) -> Void,
        onReset: @escaping () -> Void
    ) {
        self.title = title
        self.detail = detail
        self.value = value
        self.defaultValue = defaultValue
        self.mode = mode
        self.presets = presets
        self.onChange = onChange
        self.onReset = onReset
    }

    var body: some View {
        let isDefault = value == defaultValue

        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))

                    if !isDefault {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.blue)
                            .help("Customized")
                    }
                }

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 16)

            Text(defaultValue.displayName)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(isDefault ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 128, alignment: .leading)
                .help("Default: \(defaultValue.displayName)")

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

            Button(action: onReset) {
                Image(systemName: "arrow.uturn.backward.circle")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.borderless)
            .disabled(isDefault)
            .frame(width: 28)
            .help("Reset this shortcut")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
    }
}
