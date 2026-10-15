import AppKit

enum AppMenu {
    static func make(target: AnyObject) -> NSMenu {
        let menu = NSMenu()
        let settings = NSMenuItem(title: L10n.string("menu.settings"), action: #selector(AppDelegate.openSettings(_:)), keyEquivalent: ",")
        settings.target = target
        let clear = NSMenuItem(title: L10n.string("menu.clear_all"), action: #selector(AppDelegate.clearAllHistory(_:)), keyEquivalent: "")
        clear.target = target
        menu.addItem(settings)
        menu.addItem(clear)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L10n.string("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }
}
