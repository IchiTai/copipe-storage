import AppKit

enum ScreenPlacement {
    static func screenUnderMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens.first
    }

    /// 画面が 1 つも無い（ディスプレイの付け替え中など）ときは nil
    static func centeredFrame(size: NSSize) -> NSRect? {
        guard let screen = screenUnderMouse() else { return nil }
        let visible = screen.visibleFrame
        return NSRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2, width: size.width, height: size.height)
    }
}
