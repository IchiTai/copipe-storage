import AppKit
import Carbon.HIToolbox
import CopipeCore
import SwiftUI

enum KeyCommand {
    static let deleteKeyCode = UInt16(kVK_Delete)
    static let returnKeyCode = UInt16(kVK_Return)
    static let quickKeyCount = 9

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
