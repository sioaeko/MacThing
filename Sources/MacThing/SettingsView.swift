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
        .frame(width: 680, height: 520)
    }
}

private struct ShortcutSettingsPane: View {
    @EnvironmentObject private var store: SearchStore

    var body: some View {
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
                ShortcutPickerRow(
                    title: "Quick Search",
                    detail: "Open the floating search palette from anywhere",
                    value: store.globalHotkeyChoice.displayName
                ) {
                    Picker(
                        "",
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
                    .labelsHidden()
                    .frame(width: 220)
                }
            }

            GroupBox("Command Key Mapping") {
                VStack(spacing: 0) {
                    let actions = AppShortcutAction.allCases
                    ForEach(actions.indices, id: \.self) { index in
                        let action = actions[index]

                        ShortcutPickerRow(
                            title: action.displayName,
                            detail: action.settingDetail,
                            value: store.appShortcutSettings.choice(for: action).displayName
                        ) {
                            Picker(
                                "",
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
                            .labelsHidden()
                            .frame(width: 220)
                        }

                        if index < actions.index(before: actions.endIndex) {
                            Divider()
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
    }
}

private struct ShortcutPickerRow<PickerContent: View>: View {
    let title: String
    let detail: String
    let value: String
    let picker: PickerContent

    init(
        title: String,
        detail: String,
        value: String,
        @ViewBuilder picker: () -> PickerContent
    ) {
        self.title = title
        self.detail = detail
        self.value = value
        self.picker = picker()
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

            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 150, alignment: .trailing)

            picker
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
    }
}
