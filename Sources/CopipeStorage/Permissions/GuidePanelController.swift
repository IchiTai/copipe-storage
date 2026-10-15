import AppKit
import CopipeCore
import SwiftUI

final class GuidePanelController {
    static let autoCloseDelay: Duration = .seconds(20)
    static let accessibilitySettingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
    static let pasteboardSettingsURL = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Pasteboard")!

    private let panel: FloatingPanel
    private let hosting: NSHostingView<PastePermissionGuideView>
    private var autoCloseTask: Task<Void, Never>?

    init() {
        hosting = NSHostingView(rootView: PastePermissionGuideView(reason: .copiedOnly, openSettings: {}, close: {}))
        // 貼り先のアプリが別の Space にあっても、戻った先で案内が見つかるように全 Space に出す
        panel = FloatingPanel(contentSize: hosting.fittingSize, extraStyle: [.utilityWindow], collectionBehavior: [.canJoinAllSpaces, .fullScreenAuxiliary])
        panel.contentView = hosting
    }

    var isVisible: Bool { panel.isVisible }

    func show(reason: PastePermissionGuideView.Reason, near anchor: NSRect) {
        autoCloseTask?.cancel()
        hosting.rootView = PastePermissionGuideView(
            reason: reason,
            openSettings: { [weak self] in
                if reason == .readDenied {
                    NSWorkspace.shared.open(Self.pasteboardSettingsURL)
                } else {
                    PostEventPermission.request()
                    NSWorkspace.shared.open(Self.accessibilitySettingsURL)
                }
                self?.hide()
            },
            close: { [weak self] in self?.hide() }
        )
        let size = hosting.fittingSize
        panel.setFrame(NSRect(x: anchor.midX - size.width / 2, y: anchor.maxY - size.height, width: size.width, height: size.height), display: false)
        panel.orderFrontRegardless()
        guard reason == .copiedOnly || reason == .pasteFailed else { return }
        autoCloseTask = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.autoCloseDelay)
            } catch {
                return
            }
            self?.hide()
        }
    }

    func hide() {
        autoCloseTask?.cancel()
        autoCloseTask = nil
        panel.orderOut(nil)
    }
}
