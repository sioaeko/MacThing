import AppKit
import Carbon
import Foundation
import MacThingCore

struct GlobalHotkeyChoice: Codable, CaseIterable, Hashable, Identifiable, Sendable {
    var shortcut: AppShortcutChoice

    var id: String { shortcut.id }

    static var recommended: GlobalHotkeyChoice {
        .optionSpace
    }

    static let optionSpace = GlobalHotkeyChoice(shortcut: .optionSpace)
    static let controlOptionSpace = GlobalHotkeyChoice(shortcut: .controlOptionSpace)
    static let commandOptionSpace = GlobalHotkeyChoice(shortcut: .commandOptionSpace)
    static let controlCommandSpace = GlobalHotkeyChoice(shortcut: .controlCommandSpace)
    static let optionF = GlobalHotkeyChoice(shortcut: .optionF)
    static let controlOptionF = GlobalHotkeyChoice(shortcut: .controlOptionF)
    static let commandOptionF = GlobalHotkeyChoice(shortcut: .commandOptionF)
    static let commandShiftF = GlobalHotkeyChoice(shortcut: .commandShiftF)
    static let f13 = GlobalHotkeyChoice(shortcut: .f13)
    static let disabled = GlobalHotkeyChoice(shortcut: .disabled)

    static let allCases: [GlobalHotkeyChoice] = [
        .optionSpace,
        .controlOptionSpace,
        .commandOptionSpace,
        .controlCommandSpace,
        .optionF,
        .controlOptionF,
        .commandOptionF,
        .commandShiftF,
        .f13,
        .disabled
    ]

    var displayName: String {
        shortcut.displayName
    }

    fileprivate var keyCode: UInt32? {
        shortcut.key.map { UInt32($0.rawValue) }
    }

    fileprivate var modifiers: UInt32 {
        shortcut.modifiers.carbonModifierFlags
    }

    init(shortcut: AppShortcutChoice) {
        self.shortcut = shortcut
    }

    init(from decoder: Decoder) throws {
        shortcut = try AppShortcutChoice(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        try shortcut.encode(to: encoder)
    }
}

final class GlobalHotkeyController {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let action: @MainActor @Sendable () -> Void

    init(action: @escaping @MainActor @Sendable () -> Void) {
        self.action = action
    }

    deinit {
        unregister()
    }

    @discardableResult
    func register(_ choice: GlobalHotkeyChoice) -> Bool {
        unregister()
        guard let keyCode = choice.keyCode else {
            return true
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, _, userData in
            guard let userData else {
                return noErr
            }

            let controller = Unmanaged<GlobalHotkeyController>
                .fromOpaque(userData)
                .takeUnretainedValue()
            controller.fire()
            return noErr
        }

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
        guard handlerStatus == noErr else {
            unregister()
            return false
        }

        let hotKeyID = EventHotKeyID(
            signature: fourCharCode("MCTG"),
            id: 1
        )

        let hotKeyStatus = RegisterEventHotKey(
            keyCode,
            choice.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard hotKeyStatus == noErr else {
            unregister()
            return false
        }
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    private func fire() {
        Task { @MainActor [action] in
            action()
        }
    }
}

private func fourCharCode(_ value: String) -> OSType {
    value.utf8.reduce(0) { result, byte in
        (result << 8) + OSType(byte)
    }
}

private extension AppShortcutModifierFlags {
    var carbonModifierFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.command) {
            flags |= UInt32(cmdKey)
        }
        if contains(.control) {
            flags |= UInt32(controlKey)
        }
        if contains(.option) {
            flags |= UInt32(optionKey)
        }
        if contains(.shift) {
            flags |= UInt32(shiftKey)
        }
        return flags
    }
}
