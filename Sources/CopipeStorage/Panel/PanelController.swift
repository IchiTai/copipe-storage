import AppKit
import CopipeCore
import SwiftUI

final class PanelController {
    static let contentSize = NSSize(width: 520, height: 440)

    let viewModel: PanelViewModel
    var onWillShow: () async -> Void = {}
    private(set) var targetApp: NSRunningApplication?

    private let panel: HistoryPanel
    private let frontmostTracker: FrontmostAppTracker
    private var clickMonitor: Any?
    private var isPresenting = false

    init(viewModel: PanelViewModel, frontmostTracker: FrontmostAppTracker) {
        self.viewModel = viewModel
        self.frontmostTracker = frontmostTracker
        panel = HistoryPanel(contentSize: Self.contentSize)
        panel.contentView = NSHostingView(rootView: PanelRootView(model: viewModel).ignoresSafeArea())
        panel.onResignKey = { [weak self] in self?.hide() }
        panel.onEscape = { [weak self] in self?.hide() }
        panel.onCommandKey = { [viewModel] event in KeyCommand.handleCommandKey(event, model: viewModel) }
        viewModel.onClose = { [weak self] in self?.hide() }
    }

    var isVisible: Bool { panel.isVisible }
    var frame: NSRect { panel.frame }

    func toggle() {
        if isVisible { hide() } else { show() }
    }

    func show() {
        guard !isPresenting else { return }
        isPresenting = true
        targetApp = frontmostTracker.lastExternalApp
        Task { [self] in
            // 直前のコピーを取り込んでから先頭を選ぶ（取り込みは 0.5 秒ごとなので間に合っていないことがある）
            await onWillShow()
            viewModel.reset()
            if let frame = ScreenPlacement.centeredFrame(size: Self.contentSize) {
                panel.setFrame(frame, display: false)
            }
            panel.orderFrontRegardless()
            panel.makeKey()
            installClickMonitor()
            isPresenting = false
        }
    }

    func hide() {
        removeClickMonitor()
        panel.orderOut(nil)
    }

    #if DEBUG
    func snapshot(to url: URL) throws {
        guard let view = panel.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw CocoaError(.featureUnsupported)
        }
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            view.cacheDisplay(in: view.bounds, to: bitmap)
        }
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try png.write(to: url)
    }

    func sendSyntheticKey(keyCode: UInt16, characters: String, modifiers: NSEvent.ModifierFlags) {
        guard let event = NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: panel.windowNumber, context: nil, characters: characters,
            charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode
        ) else { return }
        NSApp.sendEvent(event)
    }
    #endif

    private func installClickMonitor() {
        removeClickMonitor()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, !NSMouseInRect(NSEvent.mouseLocation, self.panel.frame, false) else { return }
            self.hide()
        }
    }

    private func removeClickMonitor() {
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
        }
        clickMonitor = nil
    }
}
