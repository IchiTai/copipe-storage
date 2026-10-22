import AppKit
import Carbon.HIToolbox
import CopipeCore
import KeyboardShortcuts
import SwiftUI

enum KeyCommand {
    static let deleteKeyCode = UInt16(kVK_Delete)
    static let returnKeyCode = UInt16(kVK_Return)
    static let quickKeyCount = 9

    struct Hint {
        let shortcuts: [KeyboardShortcuts.Shortcut]
        let keyNameKey: String
        let labelKey: String

        var symbols: String {
            shortcuts.map(\.description).joined()
        }

        var spokenLabel: String {
            String(format: L10n.string("panel.hint.spoken_format"), L10n.string(keyNameKey), L10n.string(labelKey))
        }
    }

    // パネル下端の案内。handle / handleCommandKey の割り当てと対応させる
    static let hints: [Hint] = [
        Hint(shortcuts: [.init(.upArrow), .init(.downArrow)], keyNameKey: "key.up_down", labelKey: "panel.hint.select"),
        Hint(shortcuts: [.init(.return)], keyNameKey: "key.return", labelKey: "panel.hint.paste"),
        Hint(shortcuts: [.init(.return, modifiers: .shift)], keyNameKey: "key.shift_return", labelKey: "panel.hint.plain"),
        Hint(shortcuts: [.init(.return, modifiers: .command)], keyNameKey: "key.command_return", labelKey: "panel.copy"),
        Hint(shortcuts: [.init(.delete, modifiers: .command)], keyNameKey: "key.command_delete", labelKey: "panel.hint.delete"),
    ]

    static func handle(_ press: KeyPress, model: PanelViewModel) -> KeyPress.Result {
        // 日本語入力の変換中は Return（確定）と ↑↓（候補の移動）を IME に渡す
        if isComposingText() { return .ignored }
        switch press.key {
        case .upArrow:
            model.moveSelection(by: -1)
            return .handled
        case .downArrow:
            model.moveSelection(by: 1)
            return .handled
        case .return:
            model.activateSelected(mode: mode(for: press.modifiers))
            return .handled
        case .escape:
            model.onClose?()
            return .handled
        default:
            return .ignored
        }
    }

    static func handleCommandKey(_ event: NSEvent, model: PanelViewModel) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command) else { return false }
        if event.keyCode == deleteKeyCode {
            model.deleteSelected()
            return true
        }
        if event.keyCode == returnKeyCode {
            model.activateSelected(mode: .copyOnly)
            return true
        }
        if let digit = event.charactersIgnoringModifiers?.first?.wholeNumberValue, (1...quickKeyCount).contains(digit) {
            model.activate(index: digit - 1, mode: .full)
            return true
        }
        return false
    }

    static func mode(for modifiers: SwiftUI.EventModifiers) -> PasteMode {
        if modifiers.contains(.command) { return .copyOnly }
        if modifiers.contains(.shift) { return .plainText }
        return .full
    }

    static func mode(for flags: NSEvent.ModifierFlags) -> PasteMode {
        if flags.contains(.command) { return .copyOnly }
        if flags.contains(.shift) { return .plainText }
        return .full
    }

    static func isComposingText() -> Bool {
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView else { return false }
        return textView.hasMarkedText()
    }
}
