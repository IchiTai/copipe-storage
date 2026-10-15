import AppKit
import CopipeCore

final class PasteCoordinator {
    private let panelController: PanelController
    private let pasteService: PasteService
    private let guide: GuidePanelController
    private let store: any HistoryStoring

    init(panelController: PanelController, pasteService: PasteService, guide: GuidePanelController, store: any HistoryStoring) {
        self.panelController = panelController
        self.pasteService = pasteService
        self.guide = guide
        self.store = store
    }

    var isGuideVisible: Bool { guide.isVisible }

    func showReadDeniedGuide() {
        guard let anchor = ScreenPlacement.centeredFrame(size: PanelController.contentSize) else { return }
        guide.show(reason: .readDenied, near: anchor)
    }

    func showGuide(reason: PastePermissionGuideView.Reason) {
        guide.show(reason: reason, near: panelController.frame)
    }

    func activate(_ clip: Clip, mode: PasteMode) async {
        let target = panelController.targetApp
        let anchor = panelController.frame
        panelController.hide()
        let outcome = await pasteService.paste(clip, mode: mode, target: target)
        switch outcome {
        case .pasted, .copiedOnly(.requested):
            break
        case .copiedOnly(.noPostEventPermission):
            guide.show(reason: .noPermission, near: anchor)
        case .copiedOnly(.targetTerminated), .copiedOnly(.activationTimedOut):
            guide.show(reason: .copiedOnly, near: anchor)
        case .failed:
            Log.app.error("貼り付けに失敗: クリップ \(clip.id.uuidString, privacy: .public) のデータを読めないので履歴から外す")
            await store.delete(clip.id)
            guide.show(reason: .pasteFailed, near: anchor)
        }
    }
}
