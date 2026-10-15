import AppKit

enum ClearAllConfirmation {
    static func run() -> Bool {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = L10n.string("clear_all.title")
        alert.informativeText = L10n.string("clear_all.message")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.string("clear_all.confirm"))
        alert.addButton(withTitle: L10n.string("cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }
}
