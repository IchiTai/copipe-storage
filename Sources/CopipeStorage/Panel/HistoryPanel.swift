import AppKit

final class HistoryPanel: FloatingPanel {
    var onResignKey: (() -> Void)?
    var onEscape: (() -> Void)?
    var onCommandKey: ((NSEvent) -> Bool)?

    init(contentSize: NSSize) {
        super.init(contentSize: contentSize, collectionBehavior: [.moveToActiveSpace, .fullScreenAuxiliary, .stationary])
    }

    // 絞り込み欄にフォーカスを入れるため。titled 以外の窓は既定で key になれない
    override var canBecomeKey: Bool { true }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    // ⌘ 付きのキーは AppKit がここで先に配るため、SwiftUI の onKeyPress には届かない
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if onCommandKey?(event) == true { return true }
        return super.performKeyEquivalent(with: event)
    }
}
