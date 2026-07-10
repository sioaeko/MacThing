import MacThingCore
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            ShortcutSettingsPane()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            QueryServiceSettingsPane()
                .tabItem {
                    Label("Query Service", systemImage: "network")
                }
        }
        .frame(width: 760, height: 620)
    }
}

private struct QueryServiceSettingsPane: View {
    @EnvironmentObject private var store: SearchStore
    @State private var revealsToken = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Label("Query Service", systemImage: "network")
                        .font(.title3.weight(.semibold))

                    Spacer()

                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(store.queryServiceStatusText)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .help(store.queryServiceStatusText)

                    Toggle("Query Service", isOn: enabledBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .help("Enable query service")

                    Button {
                        store.resetQueryServiceSettings()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Reset query service settings")
                }

                GroupBox("Server") {
                    VStack(spacing: 0) {
                        settingsRow("Bind Address") {
                            Text("127.0.0.1")
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                        }

                        Divider()

                        settingsRow("Port") {
                            HStack(spacing: 8) {
                                TextField("Port", value: portBinding, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 92)

                                Stepper("Port", value: portBinding, in: 1_024...65_535)
                                    .labelsHidden()
                            }
                        }

                        Divider()

                        settingsRow("Endpoint") {
                            HStack(spacing: 8) {
                                Text(store.queryServiceEndpointText)
                                    .font(.system(.body, design: .monospaced))
                                    .lineLimit(1)
                                    .textSelection(.enabled)

                                Button {
                                    store.copyQueryServiceEndpoint()
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                                .buttonStyle(.borderless)
                                .help("Copy endpoint")
                            }
                        }
                    }
                }

                GroupBox("Authentication") {
                    VStack(spacing: 0) {
                        settingsRow("Bearer Token") {
                            Toggle("Require Bearer Token", isOn: authenticationBinding)
                                .toggleStyle(.switch)
                        }

                        if store.queryServiceSettings.requiresAuthentication {
                            Divider()

                            settingsRow("Token") {
                                HStack(spacing: 8) {
                                    Group {
                                        if revealsToken {
                                            TextField("Token", text: tokenBinding)
                                        } else {
                                            SecureField("Token", text: tokenBinding)
                                        }
                                    }
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(width: 380)

                                    Button {
                                        revealsToken.toggle()
                                    } label: {
                                        Image(systemName: revealsToken ? "eye.slash" : "eye")
                                    }
                                    .buttonStyle(.borderless)
                                    .help(revealsToken ? "Hide token" : "Show token")

                                    Button {
                                        store.regenerateQueryServiceAuthenticationToken()
                                    } label: {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Generate new token")

                                    Button {
                                        store.copyQueryServiceAuthenticationToken()
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Copy token")
                                }
                            }
                        }
                    }
                }

                GroupBox("Browser Access") {
                    VStack(spacing: 0) {
                        settingsRow("Allowed Origins") {
                            Picker("Allowed Origins", selection: corsPolicyBinding) {
                                ForEach(QueryServiceCORSPolicy.allCases, id: \.self) { policy in
                                    Text(policy.displayName)
                                        .tag(policy)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 360)
                        }

                        if store.queryServiceSettings.corsPolicy == .custom {
                            Divider()

                            settingsRow("Origin") {
                                TextField("https://app.example.com", text: customOriginBinding)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(width: 440)
                            }
                        }
                    }
                }

                if let validationMessage = store.queryServiceValidationMessage {
                    Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }

    private var statusColor: Color {
        if store.queryServiceIsRunning {
            return .green
        }
        return store.queryServiceSettings.isEnabled ? .orange : .secondary
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { store.queryServiceSettings.isEnabled },
            set: { store.setQueryServiceEnabled($0) }
        )
    }

    private var portBinding: Binding<Int> {
        Binding(
            get: { store.queryServiceSettings.port },
            set: { store.setQueryServicePort($0) }
        )
    }

    private var authenticationBinding: Binding<Bool> {
        Binding(
            get: { store.queryServiceSettings.requiresAuthentication },
            set: { store.setQueryServiceAuthenticationRequired($0) }
        )
    }

    private var tokenBinding: Binding<String> {
        Binding(
            get: { store.queryServiceSettings.authenticationToken },
            set: { store.setQueryServiceAuthenticationToken($0) }
        )
    }

    private var corsPolicyBinding: Binding<QueryServiceCORSPolicy> {
        Binding(
            get: { store.queryServiceSettings.corsPolicy },
            set: { store.setQueryServiceCORSPolicy($0) }
        )
    }

    private var customOriginBinding: Binding<String> {
        Binding(
            get: { store.queryServiceSettings.customAllowedOrigin },
            set: { store.setQueryServiceCustomAllowedOrigin($0) }
        )
    }

    private func settingsRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 16) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }
}

private extension QueryServiceCORSPolicy {
    var displayName: String {
        switch self {
        case .disabled:
            return "Off"
        case .loopback:
            return "Loopback"
        case .custom:
            return "Custom"
        }
    }
}

private struct ShortcutSettingsPane: View {
    @EnvironmentObject private var store: SearchStore
    @State private var shortcutSearchText = ""
    @State private var mappingFilter = ShortcutMappingFilter.all

    var body: some View {
        let query = shortcutSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedQuery = query.lowercased()
        let showsGlobalHotkey = shortcutRowMatches(
            title: "Quick Search",
            detail: "Open the floating search palette from anywhere",
            value: store.globalHotkeyChoice.shortcut,
            defaultValue: GlobalHotkeyChoice.recommended.shortcut,
            normalizedQuery: normalizedQuery,
            mappingFilter: mappingFilter
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

                HStack(spacing: 12) {
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

                    Picker("Shortcut filter", selection: $mappingFilter) {
                        ForEach(ShortcutMappingFilter.allCases) { filter in
                            Text(filter.displayName)
                                .tag(filter)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                    .help("Filter shortcut rows")
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

                if !showsGlobalHotkey && filteredActionCount(normalizedQuery: normalizedQuery) == 0 {
                    ShortcutMappingEmptyState(query: query, filter: mappingFilter)
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
                    normalizedQuery: normalizedQuery,
                    mappingFilter: mappingFilter
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
                normalizedQuery: normalizedQuery,
                mappingFilter: mappingFilter
            )
        }.count
    }

    private func shortcutRowMatches(
        title: String,
        detail: String,
        value: AppShortcutChoice,
        defaultValue: AppShortcutChoice,
        normalizedQuery: String,
        mappingFilter: ShortcutMappingFilter
    ) -> Bool {
        let isDefault = value == defaultValue
        switch mappingFilter {
        case .all:
            break
        case .modified:
            guard !isDefault else {
                return false
            }
        case .disabled:
            guard value == .disabled else {
                return false
            }
        }

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

private struct ShortcutMappingEmptyState: View {
    let query: String
    let filter: ShortcutMappingFilter

    var body: some View {
        if !query.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            ContentUnavailableView(filter.emptyTitle, systemImage: filter.emptySystemImage)
        }
    }
}

private enum ShortcutMappingFilter: String, CaseIterable, Identifiable {
    case all
    case modified
    case disabled

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all:
            return "All"
        case .modified:
            return "Modified"
        case .disabled:
            return "Disabled"
        }
    }

    var emptyTitle: String {
        switch self {
        case .all:
            return "No Shortcuts"
        case .modified:
            return "No Modified Shortcuts"
        case .disabled:
            return "No Disabled Shortcuts"
        }
    }

    var emptySystemImage: String {
        switch self {
        case .all:
            return "keyboard"
        case .modified:
            return "pencil.slash"
        case .disabled:
            return "keyboard.badge.ellipsis"
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
