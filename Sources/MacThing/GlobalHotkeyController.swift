import AppKit
import Carbon
import Foundation

enum GlobalHotkeyChoice: String, Codable, CaseIterable, Identifiable, Sendable {
    case optionSpace
    case controlOptionSpace
    case commandOptionSpace
    case controlCommandSpace
    case optionF
    case controlOptionF
    case commandOptionF
    case commandShiftF
    case f13
    case disabled

    var id: String { rawValue }

    static var recommended: GlobalHotkeyChoice {
        .optionSpace
    }

    var displayName: String {
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
        case .f13:
            return "F13"
        case .disabled:
            return "Disabled"
        }
    }

    fileprivate var keyCode: UInt32? {
        switch self {
        case .optionSpace, .controlOptionSpace, .commandOptionSpace, .controlCommandSpace:
            return UInt32(kVK_Space)
        case .optionF, .controlOptionF, .commandOptionF, .commandShiftF:
            return UInt32(kVK_ANSI_F)
        case .f13:
            return UInt32(kVK_F13)
        case .disabled:
            return nil
        }
    }

    fileprivate var modifiers: UInt32 {
        switch self {
        case .optionSpace:
            return UInt32(optionKey)
        case .controlOptionSpace:
            return UInt32(controlKey | optionKey)
        case .commandOptionSpace:
            return UInt32(cmdKey | optionKey)
        case .controlCommandSpace:
            return UInt32(controlKey | cmdKey)
        case .optionF:
            return UInt32(optionKey)
        case .controlOptionF:
            return UInt32(controlKey | optionKey)
        case .commandOptionF:
            return UInt32(cmdKey | optionKey)
        case .commandShiftF:
            return UInt32(cmdKey | shiftKey)
        case .f13:
            return 0
        case .disabled:
            return 0
        }
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
