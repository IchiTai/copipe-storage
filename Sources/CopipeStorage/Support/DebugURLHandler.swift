#if DEBUG
import AppKit
import CopipeCore
import Foundation

struct DebugURLHandler {
    let panelController: PanelController
    let pasteCoordinator: PasteCoordinator
    let settingsWindow: SettingsWindowController

    func handle(_ url: URL) {
        guard url.scheme == "copipestorage" else { return }
        let query = Dictionary(
            (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") },
            uniquingKeysWith: { first, _ in first }
        )
        switch (url.host, url.path) {
        case ("panel", "/toggle"):
            panelController.toggle()
        case ("panel", "/show"):
            panelController.show()
        case ("debug", "/snapshot"):
            guard let path = query["path"] else { return }
            do {
                try panelController.snapshot(to: URL(fileURLWithPath: path))
                Log.app.notice("snapshot written: \(path, privacy: .public)")
            } catch {
                Log.app.error("snapshot failed: \(error, privacy: .public)")
            }
        case ("debug", "/settings"):
            settingsWindow.show()
        case ("debug", "/guide"):
            switch query["reason"] {
            case "readDenied": pasteCoordinator.showReadDeniedGuide()
            case "copiedOnly": pasteCoordinator.showGuide(reason: .copiedOnly)
            case "pasteFailed": pasteCoordinator.showGuide(reason: .pasteFailed)
            default: pasteCoordinator.showGuide(reason: .noPermission)
            }
        case ("debug", "/status"):
            let model = panelController.viewModel
            Log.app.notice("status: postEvent=\(PostEventPermission.postEventGranted, privacy: .public) accessibility=\(PostEventPermission.accessibilityGranted, privacy: .public) panelVisible=\(panelController.isVisible, privacy: .public) guideVisible=\(pasteCoordinator.isGuideVisible, privacy: .public) appActive=\(NSApp.isActive, privacy: .public) target=\(panelController.targetApp?.bundleIdentifier ?? "nil", privacy: .public) selected=\(model.selectedIndex.map(String.init) ?? "nil", privacy: .public) filter=\(model.filterText, privacy: .public)")
        case ("debug", "/key"):
            var modifiers: NSEvent.ModifierFlags = []
            let mods = query["mods"] ?? ""
            if mods.contains("cmd") { modifiers.insert(.command) }
            if mods.contains("opt") { modifiers.insert(.option) }
            if mods.contains("shift") { modifiers.insert(.shift) }
            panelController.sendSyntheticKey(keyCode: UInt16(query["code"] ?? "") ?? 0, characters: query["chars"] ?? "", modifiers: modifiers)
        case ("debug", "/filter"):
            panelController.viewModel.filterText = query["text"] ?? ""
        case ("debug", "/select"):
            panelController.viewModel.moveSelection(by: Int(query["delta"] ?? "") ?? 0)
        default:
            Log.app.error("unknown debug url: \(url.absoluteString, privacy: .public)")
        }
    }
}
#endif
