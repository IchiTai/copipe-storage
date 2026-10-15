import AppKit
import SwiftUI

final class SettingsWindowController {
    private let window: NSWindow
    private var hasBeenShown = false

    init(settings: AppSettings, launchAtLogin: LaunchAtLogin) {
        let hosting = NSHostingController(rootView: SettingsView(settings: settings, launchAtLogin: launchAtLogin))
        window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable]
        window.title = L10n.string("settings.title")
        window.isReleasedWhenClosed = false
        window.toolbarStyle = .preference
    }

    func show() {
        NSApp.activate()
        if !hasBeenShown {
            window.center()
            hasBeenShown = true
        }
        window.makeKeyAndOrderFront(nil)
    }
}
