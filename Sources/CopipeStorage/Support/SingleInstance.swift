import AppKit
import CopipeCore

enum SingleInstance {
    static func anotherInstanceIsRunning() -> Bool {
        let own = ProcessInfo.processInfo.processIdentifier
        return NSRunningApplication.runningApplications(withBundleIdentifier: AppIdentity.bundleIdentifier)
            .contains { $0.processIdentifier != own }
    }

    static func showAlreadyRunningAlert() {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = L10n.string("alert.already_running.title")
        alert.informativeText = L10n.string("alert.already_running.message")
        alert.addButton(withTitle: L10n.string("ok"))
        alert.runModal()
    }
}
