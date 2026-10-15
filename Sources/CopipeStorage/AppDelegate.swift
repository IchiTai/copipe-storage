import AppKit
import CopipeCore
import KeyboardShortcuts

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private var store: FileHistoryStore?
    private var frontmostTracker: FrontmostAppTracker?
    private var captureService: CaptureService?
    private var panelController: PanelController?
    private var pasteCoordinator: PasteCoordinator?
    private var settings: AppSettings?
    private var launchAtLogin: LaunchAtLogin?
    private var settingsWindow: SettingsWindowController?
    private lazy var contextMenu = AppMenu.make(target: self)
    #if DEBUG
    private var debugURLHandler: DebugURLHandler?
    #endif

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.mainMenu = AppMainMenu.make()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 2 つ動くと同じ保存先を取り合い、互いのクリップを消してしまう
        if SingleInstance.anotherInstanceIsRunning() {
            SingleInstance.showAlreadyRunningAlert()
            NSApp.terminate(nil)
            return
        }

        let settings = AppSettings()
        let layout = StorageLayout.defaultLayout()
        let store = FileHistoryStore(layout: layout, limits: settings.limits)
        let tracker = FrontmostAppTracker()
        let capture = CaptureService(store: store, frontmostBundleID: { tracker.lastExternalBundleID })
        let guide = GuidePanelController()
        let viewModel = PanelViewModel(store: store, layout: layout)
        let panel = PanelController(viewModel: viewModel, frontmostTracker: tracker)
        let pasteService = PasteService(store: store, capture: capture)
        let coordinator = PasteCoordinator(panelController: panel, pasteService: pasteService, guide: guide, store: store)
        let launchAtLogin = LaunchAtLogin()
        let settingsWindow = SettingsWindowController(settings: settings, launchAtLogin: launchAtLogin)
        let statusItem = StatusItemController(menu: contextMenu)

        panel.onWillShow = {
            guide.hide()
            await capture.tick()
        }
        viewModel.onActivate = { clip, mode in Task { await coordinator.activate(clip, mode: mode) } }
        viewModel.openMenu = { [weak self] in
            self?.contextMenu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        }
        statusItem.onPrimaryClick = { panel.toggle() }
        settings.onLimitsChange = { limits in Task { await store.updateLimits(limits) } }
        capture.onReadBlockedChange = { blocked in
            if blocked { coordinator.showReadDeniedGuide() }
        }
        KeyboardShortcuts.onKeyDown(for: .togglePanel) { panel.toggle() }

        self.settings = settings
        self.store = store
        frontmostTracker = tracker
        captureService = capture
        panelController = panel
        pasteCoordinator = coordinator
        self.launchAtLogin = launchAtLogin
        self.settingsWindow = settingsWindow
        statusItemController = statusItem
        #if DEBUG
        debugURLHandler = DebugURLHandler(panelController: panel, pasteCoordinator: coordinator, settingsWindow: settingsWindow)
        #endif

        Task {
            await store.load()
            viewModel.startObserving()
            capture.start()
        }
    }

    @objc func openSettings(_ sender: Any?) {
        panelController?.hide()
        settingsWindow?.show()
    }

    @objc func clearAllHistory(_ sender: Any?) {
        panelController?.hide()
        guard ClearAllConfirmation.run(), let store else { return }
        Task { await store.deleteAll() }
    }

    #if DEBUG
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            debugURLHandler?.handle(url)
        }
    }
    #endif

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        captureService?.stop()
        guard let store else { return .terminateNow }
        Task {
            await store.flush()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
