import AppKit

class FloatingPanel: NSPanel {
    init(contentSize: NSSize, extraStyle: NSWindow.StyleMask = [], collectionBehavior: NSWindow.CollectionBehavior) {
        super.init(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: NSWindow.StyleMask([.nonactivatingPanel, .titled, .fullSizeContentView]).union(extraStyle),
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        self.collectionBehavior = collectionBehavior
        // NSPanel の既定は true。自アプリがアクティブでないままパネルを使うので打ち消す
        hidesOnDeactivate = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = false
        animationBehavior = .none
        isReleasedWhenClosed = false
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            standardWindowButton(button)?.isHidden = true
        }
    }

    override var canBecomeMain: Bool { false }
}
