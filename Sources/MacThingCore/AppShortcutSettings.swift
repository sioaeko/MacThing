import Foundation

public enum AppShortcutAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case quickSearch
    case showWindow
    case reindex
    case toggleMatchPath
    case toggleFuzzyMatching
    case toggleCaseSensitive
    case exportVisibleResults

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .quickSearch:
            return "Quick Search"
        case .showWindow:
            return "Show Window"
        case .reindex:
            return "Reindex"
        case .toggleMatchPath:
            return "Toggle Path Match"
        case .toggleFuzzyMatching:
            return "Toggle Fuzzy Matching"
        case .toggleCaseSensitive:
            return "Toggle Case Sensitive"
        case .exportVisibleResults:
            return "Export Visible Results"
        }
    }

    public var availableChoices: [AppShortcutChoice] {
        switch self {
        case .quickSearch:
            return [
                .optionSpace,
                .controlOptionSpace,
                .commandOptionSpace,
                .commandShiftF,
                .optionF,
                .controlOptionF,
                .commandOptionF,
                .disabled
            ]
        case .showWindow:
            return [
                .command0,
                .command1,
                .controlCommandSpace,
                .controlCommandM,
                .disabled
            ]
        case .reindex:
            return [
                .commandShiftR,
                .controlCommandR,
                .commandOptionR,
                .disabled
            ]
        case .toggleMatchPath:
            return [
                .commandOptionP,
                .controlOptionP,
                .disabled
            ]
        case .toggleFuzzyMatching:
            return [
                .commandOptionU,
                .controlOptionU,
                .commandOptionF,
                .disabled
            ]
        case .toggleCaseSensitive:
            return [
                .commandOptionC,
                .controlOptionC,
                .disabled
            ]
        case .exportVisibleResults:
            return [
                .commandShiftE,
                .commandOptionE,
                .disabled
            ]
        }
    }
}

public enum AppShortcutChoice: String, Codable, CaseIterable, Identifiable, Sendable {
    case optionSpace
    case controlOptionSpace
    case commandOptionSpace
    case controlCommandSpace
    case optionF
    case controlOptionF
    case commandOptionF
    case commandShiftF
    case command0
    case command1
    case controlCommandM
    case commandShiftR
    case controlCommandR
    case commandOptionR
    case commandOptionP
    case controlOptionP
    case commandOptionU
    case controlOptionU
    case commandOptionC
    case controlOptionC
    case commandShiftE
    case commandOptionE
    case disabled

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .optionSpace:
            return "Option Space"
        case .controlOptionSpace:
            return "Control Option Space"
        case .commandOptionSpace:
            return "Command Option Space"
        case .controlCommandSpace:
            return "Control Command Space"
        case .optionF:
            return "Option F"
        case .controlOptionF:
            return "Control Option F"
        case .commandOptionF:
            return "Command Option F"
        case .commandShiftF:
            return "Command Shift F"
        case .command0:
            return "Command 0"
        case .command1:
            return "Command 1"
        case .controlCommandM:
            return "Control Command M"
        case .commandShiftR:
            return "Command Shift R"
        case .controlCommandR:
            return "Control Command R"
        case .commandOptionR:
            return "Command Option R"
        case .commandOptionP:
            return "Command Option P"
        case .controlOptionP:
            return "Control Option P"
        case .commandOptionU:
            return "Command Option U"
        case .controlOptionU:
            return "Control Option U"
        case .commandOptionC:
            return "Command Option C"
        case .controlOptionC:
            return "Control Option C"
        case .commandShiftE:
            return "Command Shift E"
        case .commandOptionE:
            return "Command Option E"
        case .disabled:
            return "Disabled"
        }
    }
}

public struct AppShortcutSettings: Codable, Hashable, Sendable {
    public var quickSearch: AppShortcutChoice
    public var showWindow: AppShortcutChoice
    public var reindex: AppShortcutChoice
    public var toggleMatchPath: AppShortcutChoice
    public var toggleFuzzyMatching: AppShortcutChoice
    public var toggleCaseSensitive: AppShortcutChoice
    public var exportVisibleResults: AppShortcutChoice

    public init(
        quickSearch: AppShortcutChoice = .optionSpace,
        showWindow: AppShortcutChoice = .command0,
        reindex: AppShortcutChoice = .commandShiftR,
        toggleMatchPath: AppShortcutChoice = .disabled,
        toggleFuzzyMatching: AppShortcutChoice = .disabled,
        toggleCaseSensitive: AppShortcutChoice = .disabled,
        exportVisibleResults: AppShortcutChoice = .disabled
    ) {
        self.quickSearch = quickSearch
        self.showWindow = showWindow
        self.reindex = reindex
        self.toggleMatchPath = toggleMatchPath
        self.toggleFuzzyMatching = toggleFuzzyMatching
        self.toggleCaseSensitive = toggleCaseSensitive
        self.exportVisibleResults = exportVisibleResults
    }

    public static let defaults = AppShortcutSettings()

    public func choice(for action: AppShortcutAction) -> AppShortcutChoice {
        switch action {
        case .quickSearch:
            return quickSearch
        case .showWindow:
            return showWindow
        case .reindex:
            return reindex
        case .toggleMatchPath:
            return toggleMatchPath
        case .toggleFuzzyMatching:
            return toggleFuzzyMatching
        case .toggleCaseSensitive:
            return toggleCaseSensitive
        case .exportVisibleResults:
            return exportVisibleResults
        }
    }

    public mutating func set(_ choice: AppShortcutChoice, for action: AppShortcutAction) {
        if choice != .disabled {
            clearDuplicate(choice, except: action)
        }

        switch action {
        case .quickSearch:
            quickSearch = choice
        case .showWindow:
            showWindow = choice
        case .reindex:
            reindex = choice
        case .toggleMatchPath:
            toggleMatchPath = choice
        case .toggleFuzzyMatching:
            toggleFuzzyMatching = choice
        case .toggleCaseSensitive:
            toggleCaseSensitive = choice
        case .exportVisibleResults:
            exportVisibleResults = choice
        }
    }

    public func setting(_ choice: AppShortcutChoice, for action: AppShortcutAction) -> AppShortcutSettings {
        var settings = self
        settings.set(choice, for: action)
        return settings
    }

    private mutating func clearDuplicate(_ choice: AppShortcutChoice, except action: AppShortcutAction) {
        for existingAction in AppShortcutAction.allCases where existingAction != action {
            guard self.choice(for: existingAction) == choice else {
                continue
            }
            setDirect(.disabled, for: existingAction)
        }
    }

    private mutating func setDirect(_ choice: AppShortcutChoice, for action: AppShortcutAction) {
        switch action {
        case .quickSearch:
            quickSearch = choice
        case .showWindow:
            showWindow = choice
        case .reindex:
            reindex = choice
        case .toggleMatchPath:
            toggleMatchPath = choice
        case .toggleFuzzyMatching:
            toggleFuzzyMatching = choice
        case .toggleCaseSensitive:
            toggleCaseSensitive = choice
        case .exportVisibleResults:
            exportVisibleResults = choice
        }
    }
}
