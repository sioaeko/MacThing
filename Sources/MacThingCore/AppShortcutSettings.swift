import Foundation

public enum AppShortcutAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case quickSearch
    case showWindow
    case reindex
    case toggleMatchPath
    case toggleFuzzyMatching
    case toggleCaseSensitive
    case toggleRegexMatching
    case toggleWholeWordMatching
    case toggleDiacriticSensitive
    case exportVisibleResults

    public var id: String { rawValue }

    public var settingsSection: AppShortcutSection {
        switch self {
        case .quickSearch, .showWindow, .reindex, .exportVisibleResults:
            return .applicationCommands
        case .toggleMatchPath, .toggleFuzzyMatching, .toggleCaseSensitive,
             .toggleRegexMatching, .toggleWholeWordMatching, .toggleDiacriticSensitive:
            return .searchOptionToggles
        }
    }

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
        case .toggleRegexMatching:
            return "Toggle Regex Matching"
        case .toggleWholeWordMatching:
            return "Toggle Whole Word"
        case .toggleDiacriticSensitive:
            return "Toggle Diacritics"
        case .exportVisibleResults:
            return "Export Visible Results"
        }
    }

    public var settingDetail: String {
        switch self {
        case .quickSearch:
            return "Open the floating search palette"
        case .showWindow:
            return "Bring the main MacThing window forward"
        case .reindex:
            return "Rebuild the enabled indexes"
        case .toggleMatchPath:
            return "Switch path matching on or off"
        case .toggleFuzzyMatching:
            return "Switch fuzzy matching on or off"
        case .toggleCaseSensitive:
            return "Switch case-sensitive matching on or off"
        case .toggleRegexMatching:
            return "Switch regex matching on or off"
        case .toggleWholeWordMatching:
            return "Switch whole-word matching on or off"
        case .toggleDiacriticSensitive:
            return "Switch diacritic-sensitive matching on or off"
        case .exportVisibleResults:
            return "Export the current result list"
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
        case .toggleRegexMatching:
            return [
                .commandOptionX,
                .controlOptionX,
                .disabled
            ]
        case .toggleWholeWordMatching:
            return [
                .commandOptionW,
                .controlOptionW,
                .disabled
            ]
        case .toggleDiacriticSensitive:
            return [
                .commandOptionD,
                .controlOptionD,
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

public enum AppShortcutSection: String, CaseIterable, Identifiable, Sendable {
    case applicationCommands = "Application Commands"
    case searchOptionToggles = "Search Option Toggles"

    public var id: String { rawValue }
}

public struct AppShortcutModifierFlags: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let command = AppShortcutModifierFlags(rawValue: 1 << 0)
    public static let control = AppShortcutModifierFlags(rawValue: 1 << 1)
    public static let option = AppShortcutModifierFlags(rawValue: 1 << 2)
    public static let shift = AppShortcutModifierFlags(rawValue: 1 << 3)

    public var displayParts: [String] {
        var parts: [String] = []
        if contains(.control) {
            parts.append("Control")
        }
        if contains(.command) {
            parts.append("Command")
        }
        if contains(.option) {
            parts.append("Option")
        }
        if contains(.shift) {
            parts.append("Shift")
        }
        return parts
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(UInt8.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public enum AppShortcutKey: UInt16, Codable, CaseIterable, Identifiable, Sendable {
    case a = 0
    case s = 1
    case d = 2
    case f = 3
    case h = 4
    case g = 5
    case z = 6
    case x = 7
    case c = 8
    case v = 9
    case b = 11
    case q = 12
    case w = 13
    case e = 14
    case r = 15
    case y = 16
    case t = 17
    case one = 18
    case two = 19
    case three = 20
    case four = 21
    case six = 22
    case five = 23
    case equals = 24
    case nine = 25
    case seven = 26
    case minus = 27
    case eight = 28
    case zero = 29
    case rightBracket = 30
    case o = 31
    case u = 32
    case leftBracket = 33
    case i = 34
    case p = 35
    case returnKey = 36
    case l = 37
    case j = 38
    case quote = 39
    case k = 40
    case semicolon = 41
    case backslash = 42
    case comma = 43
    case slash = 44
    case n = 45
    case m = 46
    case period = 47
    case tab = 48
    case space = 49
    case grave = 50
    case delete = 51
    case escape = 53
    case f17 = 64
    case f18 = 79
    case f19 = 80
    case f20 = 90
    case f5 = 96
    case f6 = 97
    case f7 = 98
    case f3 = 99
    case f8 = 100
    case f9 = 101
    case f11 = 103
    case f13 = 105
    case f16 = 106
    case f14 = 107
    case f10 = 109
    case f12 = 111
    case f15 = 113
    case home = 115
    case pageUp = 116
    case forwardDelete = 117
    case f4 = 118
    case end = 119
    case f2 = 120
    case pageDown = 121
    case f1 = 122
    case leftArrow = 123
    case rightArrow = 124
    case downArrow = 125
    case upArrow = 126

    public var id: UInt16 { rawValue }

    public var displayName: String {
        switch self {
        case .a: return "A"
        case .s: return "S"
        case .d: return "D"
        case .f: return "F"
        case .h: return "H"
        case .g: return "G"
        case .z: return "Z"
        case .x: return "X"
        case .c: return "C"
        case .v: return "V"
        case .b: return "B"
        case .q: return "Q"
        case .w: return "W"
        case .e: return "E"
        case .r: return "R"
        case .y: return "Y"
        case .t: return "T"
        case .one: return "1"
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .zero: return "0"
        case .equals: return "="
        case .minus: return "-"
        case .rightBracket: return "]"
        case .leftBracket: return "["
        case .quote: return "'"
        case .semicolon: return ";"
        case .backslash: return "\\"
        case .comma: return ","
        case .slash: return "/"
        case .period: return "."
        case .returnKey: return "Return"
        case .tab: return "Tab"
        case .space: return "Space"
        case .grave: return "`"
        case .delete: return "Delete"
        case .escape: return "Escape"
        case .f1: return "F1"
        case .f2: return "F2"
        case .f3: return "F3"
        case .f4: return "F4"
        case .f5: return "F5"
        case .f6: return "F6"
        case .f7: return "F7"
        case .f8: return "F8"
        case .f9: return "F9"
        case .f10: return "F10"
        case .f11: return "F11"
        case .f12: return "F12"
        case .f13: return "F13"
        case .f14: return "F14"
        case .f15: return "F15"
        case .f16: return "F16"
        case .f17: return "F17"
        case .f18: return "F18"
        case .f19: return "F19"
        case .f20: return "F20"
        case .home: return "Home"
        case .pageUp: return "Page Up"
        case .forwardDelete: return "Forward Delete"
        case .end: return "End"
        case .pageDown: return "Page Down"
        case .leftArrow: return "Left Arrow"
        case .rightArrow: return "Right Arrow"
        case .downArrow: return "Down Arrow"
        case .upArrow: return "Up Arrow"
        case .i: return "I"
        case .j: return "J"
        case .k: return "K"
        case .l: return "L"
        case .m: return "M"
        case .n: return "N"
        case .o: return "O"
        case .p: return "P"
        case .u: return "U"
        }
    }

    public var keyEquivalentLiteral: String? {
        switch self {
        case .a: return "a"
        case .s: return "s"
        case .d: return "d"
        case .f: return "f"
        case .h: return "h"
        case .g: return "g"
        case .z: return "z"
        case .x: return "x"
        case .c: return "c"
        case .v: return "v"
        case .b: return "b"
        case .q: return "q"
        case .w: return "w"
        case .e: return "e"
        case .r: return "r"
        case .y: return "y"
        case .t: return "t"
        case .one: return "1"
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .zero: return "0"
        case .equals: return "="
        case .minus: return "-"
        case .rightBracket: return "]"
        case .leftBracket: return "["
        case .quote: return "'"
        case .semicolon: return ";"
        case .backslash: return "\\"
        case .comma: return ","
        case .slash: return "/"
        case .period: return "."
        case .space: return " "
        case .grave: return "`"
        case .i: return "i"
        case .j: return "j"
        case .k: return "k"
        case .l: return "l"
        case .m: return "m"
        case .n: return "n"
        case .o: return "o"
        case .p: return "p"
        case .u: return "u"
        case .returnKey, .tab, .delete, .escape, .f1, .f2, .f3, .f4, .f5, .f6,
             .f7, .f8, .f9, .f10, .f11, .f12, .f13, .f14, .f15, .f16, .f17,
             .f18, .f19, .f20, .home, .pageUp, .forwardDelete, .end, .pageDown,
             .leftArrow, .rightArrow, .downArrow, .upArrow:
            return nil
        }
    }

    public var isFunctionKey: Bool {
        switch self {
        case .f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10, .f11, .f12,
             .f13, .f14, .f15, .f16, .f17, .f18, .f19, .f20:
            return true
        default:
            return false
        }
    }

    public var supportsMenuCommand: Bool {
        keyEquivalentLiteral != nil || [
            .returnKey,
            .tab,
            .delete,
            .escape,
            .home,
            .pageUp,
            .forwardDelete,
            .end,
            .pageDown,
            .leftArrow,
            .rightArrow,
            .downArrow,
            .upArrow
        ].contains(self)
    }
}

public struct AppShortcutChoice: Codable, Hashable, Identifiable, Sendable {
    public var key: AppShortcutKey?
    public var modifiers: AppShortcutModifierFlags

    public var id: String { storageName }
    public var isEnabled: Bool { key != nil }

    public init(key: AppShortcutKey?, modifiers: AppShortcutModifierFlags = []) {
        self.key = key
        self.modifiers = key == nil ? [] : modifiers
    }

    public init(key: AppShortcutKey, modifiers: AppShortcutModifierFlags = []) {
        self.init(key: Optional(key), modifiers: modifiers)
    }

    public var displayName: String {
        guard let key else {
            return "Disabled"
        }

        let parts = modifiers.displayParts + [key.displayName]
        return parts.joined(separator: " ")
    }

    public static let optionSpace = AppShortcutChoice(key: .space, modifiers: [.option])
    public static let controlOptionSpace = AppShortcutChoice(key: .space, modifiers: [.control, .option])
    public static let commandOptionSpace = AppShortcutChoice(key: .space, modifiers: [.command, .option])
    public static let controlCommandSpace = AppShortcutChoice(key: .space, modifiers: [.control, .command])
    public static let optionF = AppShortcutChoice(key: .f, modifiers: [.option])
    public static let controlOptionF = AppShortcutChoice(key: .f, modifiers: [.control, .option])
    public static let commandOptionF = AppShortcutChoice(key: .f, modifiers: [.command, .option])
    public static let commandShiftF = AppShortcutChoice(key: .f, modifiers: [.command, .shift])
    public static let command0 = AppShortcutChoice(key: .zero, modifiers: [.command])
    public static let command1 = AppShortcutChoice(key: .one, modifiers: [.command])
    public static let controlCommandM = AppShortcutChoice(key: .m, modifiers: [.control, .command])
    public static let commandShiftR = AppShortcutChoice(key: .r, modifiers: [.command, .shift])
    public static let controlCommandR = AppShortcutChoice(key: .r, modifiers: [.control, .command])
    public static let commandOptionR = AppShortcutChoice(key: .r, modifiers: [.command, .option])
    public static let commandOptionP = AppShortcutChoice(key: .p, modifiers: [.command, .option])
    public static let controlOptionP = AppShortcutChoice(key: .p, modifiers: [.control, .option])
    public static let commandOptionU = AppShortcutChoice(key: .u, modifiers: [.command, .option])
    public static let controlOptionU = AppShortcutChoice(key: .u, modifiers: [.control, .option])
    public static let commandOptionC = AppShortcutChoice(key: .c, modifiers: [.command, .option])
    public static let controlOptionC = AppShortcutChoice(key: .c, modifiers: [.control, .option])
    public static let commandOptionD = AppShortcutChoice(key: .d, modifiers: [.command, .option])
    public static let controlOptionD = AppShortcutChoice(key: .d, modifiers: [.control, .option])
    public static let commandOptionW = AppShortcutChoice(key: .w, modifiers: [.command, .option])
    public static let controlOptionW = AppShortcutChoice(key: .w, modifiers: [.control, .option])
    public static let commandOptionX = AppShortcutChoice(key: .x, modifiers: [.command, .option])
    public static let controlOptionX = AppShortcutChoice(key: .x, modifiers: [.control, .option])
    public static let commandShiftE = AppShortcutChoice(key: .e, modifiers: [.command, .shift])
    public static let commandOptionE = AppShortcutChoice(key: .e, modifiers: [.command, .option])
    public static let f13 = AppShortcutChoice(key: .f13)
    public static let disabled = AppShortcutChoice(key: nil)

    public init(from decoder: Decoder) throws {
        let singleValueContainer = try decoder.singleValueContainer()
        if let storageName = try? singleValueContainer.decode(String.self) {
            guard let choice = AppShortcutChoice(storageName: storageName) else {
                throw DecodingError.dataCorruptedError(
                    in: singleValueContainer,
                    debugDescription: "Unknown shortcut choice \(storageName)"
                )
            }
            self = choice
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let key = try container.decodeIfPresent(AppShortcutKey.self, forKey: .key)
        let modifiers = try container.decodeIfPresent(AppShortcutModifierFlags.self, forKey: .modifiers) ?? []
        self.init(key: key, modifiers: modifiers)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storageName)
    }

    private enum CodingKeys: String, CodingKey {
        case key
        case modifiers
    }

    private init?(storageName: String) {
        if let legacyChoice = Self.legacyChoices[storageName] {
            self = legacyChoice
            return
        }

        let parts = storageName.split(separator: ":")
        guard parts.count == 3,
              parts[0] == "custom",
              let modifierRawValue = UInt8(parts[1]),
              let keyRawValue = UInt16(parts[2]),
              let key = AppShortcutKey(rawValue: keyRawValue) else {
            return nil
        }
        self.init(key: key, modifiers: AppShortcutModifierFlags(rawValue: modifierRawValue))
    }

    private var storageName: String {
        if let legacyName = Self.legacyChoices.first(where: { $0.value == self })?.key {
            return legacyName
        }

        guard let key else {
            return "disabled"
        }
        return "custom:\(modifiers.rawValue):\(key.rawValue)"
    }

    private static let legacyChoices: [String: AppShortcutChoice] = [
        "optionSpace": .optionSpace,
        "controlOptionSpace": .controlOptionSpace,
        "commandOptionSpace": .commandOptionSpace,
        "controlCommandSpace": .controlCommandSpace,
        "optionF": .optionF,
        "controlOptionF": .controlOptionF,
        "commandOptionF": .commandOptionF,
        "commandShiftF": .commandShiftF,
        "command0": .command0,
        "command1": .command1,
        "controlCommandM": .controlCommandM,
        "commandShiftR": .commandShiftR,
        "controlCommandR": .controlCommandR,
        "commandOptionR": .commandOptionR,
        "commandOptionP": .commandOptionP,
        "controlOptionP": .controlOptionP,
        "commandOptionU": .commandOptionU,
        "controlOptionU": .controlOptionU,
        "commandOptionC": .commandOptionC,
        "controlOptionC": .controlOptionC,
        "commandOptionD": .commandOptionD,
        "controlOptionD": .controlOptionD,
        "commandOptionW": .commandOptionW,
        "controlOptionW": .controlOptionW,
        "commandOptionX": .commandOptionX,
        "controlOptionX": .controlOptionX,
        "commandShiftE": .commandShiftE,
        "commandOptionE": .commandOptionE,
        "f13": .f13,
        "disabled": .disabled
    ]
}

public struct AppShortcutSettings: Codable, Hashable, Sendable {
    public var quickSearch: AppShortcutChoice
    public var showWindow: AppShortcutChoice
    public var reindex: AppShortcutChoice
    public var toggleMatchPath: AppShortcutChoice
    public var toggleFuzzyMatching: AppShortcutChoice
    public var toggleCaseSensitive: AppShortcutChoice
    public var toggleRegexMatching: AppShortcutChoice
    public var toggleWholeWordMatching: AppShortcutChoice
    public var toggleDiacriticSensitive: AppShortcutChoice
    public var exportVisibleResults: AppShortcutChoice

    public init(
        quickSearch: AppShortcutChoice = .optionSpace,
        showWindow: AppShortcutChoice = .command0,
        reindex: AppShortcutChoice = .commandShiftR,
        toggleMatchPath: AppShortcutChoice = .disabled,
        toggleFuzzyMatching: AppShortcutChoice = .disabled,
        toggleCaseSensitive: AppShortcutChoice = .disabled,
        toggleRegexMatching: AppShortcutChoice = .disabled,
        toggleWholeWordMatching: AppShortcutChoice = .disabled,
        toggleDiacriticSensitive: AppShortcutChoice = .disabled,
        exportVisibleResults: AppShortcutChoice = .disabled
    ) {
        self.quickSearch = quickSearch
        self.showWindow = showWindow
        self.reindex = reindex
        self.toggleMatchPath = toggleMatchPath
        self.toggleFuzzyMatching = toggleFuzzyMatching
        self.toggleCaseSensitive = toggleCaseSensitive
        self.toggleRegexMatching = toggleRegexMatching
        self.toggleWholeWordMatching = toggleWholeWordMatching
        self.toggleDiacriticSensitive = toggleDiacriticSensitive
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
        case .toggleRegexMatching:
            return toggleRegexMatching
        case .toggleWholeWordMatching:
            return toggleWholeWordMatching
        case .toggleDiacriticSensitive:
            return toggleDiacriticSensitive
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
        case .toggleRegexMatching:
            toggleRegexMatching = choice
        case .toggleWholeWordMatching:
            toggleWholeWordMatching = choice
        case .toggleDiacriticSensitive:
            toggleDiacriticSensitive = choice
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
        case .toggleRegexMatching:
            toggleRegexMatching = choice
        case .toggleWholeWordMatching:
            toggleWholeWordMatching = choice
        case .toggleDiacriticSensitive:
            toggleDiacriticSensitive = choice
        case .exportVisibleResults:
            exportVisibleResults = choice
        }
    }

    private enum CodingKeys: String, CodingKey {
        case quickSearch
        case showWindow
        case reindex
        case toggleMatchPath
        case toggleFuzzyMatching
        case toggleCaseSensitive
        case toggleRegexMatching
        case toggleWholeWordMatching
        case toggleDiacriticSensitive
        case exportVisibleResults
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            quickSearch: try container.decodeIfPresent(AppShortcutChoice.self, forKey: .quickSearch) ?? .optionSpace,
            showWindow: try container.decodeIfPresent(AppShortcutChoice.self, forKey: .showWindow) ?? .command0,
            reindex: try container.decodeIfPresent(AppShortcutChoice.self, forKey: .reindex) ?? .commandShiftR,
            toggleMatchPath: try container.decodeIfPresent(AppShortcutChoice.self, forKey: .toggleMatchPath) ?? .disabled,
            toggleFuzzyMatching: try container.decodeIfPresent(AppShortcutChoice.self, forKey: .toggleFuzzyMatching) ?? .disabled,
            toggleCaseSensitive: try container.decodeIfPresent(AppShortcutChoice.self, forKey: .toggleCaseSensitive) ?? .disabled,
            toggleRegexMatching: try container.decodeIfPresent(AppShortcutChoice.self, forKey: .toggleRegexMatching) ?? .disabled,
            toggleWholeWordMatching: try container.decodeIfPresent(AppShortcutChoice.self, forKey: .toggleWholeWordMatching) ?? .disabled,
            toggleDiacriticSensitive: try container.decodeIfPresent(AppShortcutChoice.self, forKey: .toggleDiacriticSensitive) ?? .disabled,
            exportVisibleResults: try container.decodeIfPresent(AppShortcutChoice.self, forKey: .exportVisibleResults) ?? .disabled
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(quickSearch, forKey: .quickSearch)
        try container.encode(showWindow, forKey: .showWindow)
        try container.encode(reindex, forKey: .reindex)
        try container.encode(toggleMatchPath, forKey: .toggleMatchPath)
        try container.encode(toggleFuzzyMatching, forKey: .toggleFuzzyMatching)
        try container.encode(toggleCaseSensitive, forKey: .toggleCaseSensitive)
        try container.encode(toggleRegexMatching, forKey: .toggleRegexMatching)
        try container.encode(toggleWholeWordMatching, forKey: .toggleWholeWordMatching)
        try container.encode(toggleDiacriticSensitive, forKey: .toggleDiacriticSensitive)
        try container.encode(exportVisibleResults, forKey: .exportVisibleResults)
    }
}
