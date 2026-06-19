import AppKit
import MacThingCore
import SwiftUI

struct ShortcutRecorder: NSViewRepresentable {
    enum Mode {
        case globalHotkey
        case menuCommand
    }

    let value: AppShortcutChoice
    let mode: Mode
    let onChange: (AppShortcutChoice) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton(frame: .zero)
        button.mode = mode
        button.value = value
        button.onChange = onChange
        return button
    }

    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        button.mode = mode
        button.value = value
        button.onChange = onChange
    }
}

final class ShortcutRecorderButton: NSButton {
    var mode: ShortcutRecorder.Mode = .menuCommand
    var onChange: ((AppShortcutChoice) -> Void)?
    var value: AppShortcutChoice = .disabled {
        didSet {
            if !isRecording {
                refreshTitle()
            }
        }
    }

    private var isRecording = false
    private var feedbackTitle: String?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        beginRecording()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let modifiers = AppShortcutModifierFlags(eventModifierFlags: event.modifierFlags)

        if event.keyCode == AppShortcutKey.escape.rawValue, modifiers.isEmpty {
            endRecording()
            return
        }

        if event.keyCode == AppShortcutKey.delete.rawValue, modifiers.isEmpty {
            onChange?(.disabled)
            endRecording()
            return
        }

        guard let key = AppShortcutKey(rawValue: event.keyCode) else {
            reject("Unsupported key")
            return
        }

        guard mode.allows(key: key, modifiers: modifiers) else {
            reject(mode.rejectionTitle(for: key, modifiers: modifiers))
            return
        }

        onChange?(AppShortcutChoice(key: key, modifiers: modifiers))
        endRecording()
    }

    override func resignFirstResponder() -> Bool {
        if isRecording {
            endRecording()
        }
        return super.resignFirstResponder()
    }

    private func configure() {
        bezelStyle = .rounded
        setButtonType(.momentaryChange)
        isBordered = true
        imagePosition = .noImage
        alignment = .center
        font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        focusRingType = .exterior
        toolTip = "Click, then press a shortcut. Escape cancels; Delete clears."
        refreshTitle()
    }

    private func beginRecording() {
        isRecording = true
        feedbackTitle = nil
        window?.makeFirstResponder(self)
        refreshTitle()
    }

    private func endRecording() {
        isRecording = false
        feedbackTitle = nil
        refreshTitle()
    }

    private func reject(_ message: String) {
        NSSound.beep()
        feedbackTitle = message
        refreshTitle()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard let self, self.isRecording, self.feedbackTitle == message else {
                return
            }
            self.feedbackTitle = nil
            self.refreshTitle()
        }
    }

    private func refreshTitle() {
        if let feedbackTitle {
            title = feedbackTitle
        } else if isRecording {
            title = "Press shortcut"
        } else {
            title = value.displayName
        }
    }
}

private extension ShortcutRecorder.Mode {
    func allows(key: AppShortcutKey, modifiers: AppShortcutModifierFlags) -> Bool {
        switch self {
        case .globalHotkey:
            return key.isFunctionKey || !modifiers.isEmpty
        case .menuCommand:
            return key.supportsMenuCommand && !modifiers.isEmpty
        }
    }

    func rejectionTitle(for key: AppShortcutKey, modifiers: AppShortcutModifierFlags) -> String {
        switch self {
        case .globalHotkey:
            return key.isFunctionKey || !modifiers.isEmpty ? "Unsupported key" : "Add modifier"
        case .menuCommand:
            return key.supportsMenuCommand && !modifiers.isEmpty ? "Unsupported key" : "Add modifier"
        }
    }
}

private extension AppShortcutModifierFlags {
    init(eventModifierFlags: NSEvent.ModifierFlags) {
        var modifiers: AppShortcutModifierFlags = []
        if eventModifierFlags.contains(.command) {
            modifiers.insert(.command)
        }
        if eventModifierFlags.contains(.control) {
            modifiers.insert(.control)
        }
        if eventModifierFlags.contains(.option) {
            modifiers.insert(.option)
        }
        if eventModifierFlags.contains(.shift) {
            modifiers.insert(.shift)
        }
        self = modifiers
    }
}
