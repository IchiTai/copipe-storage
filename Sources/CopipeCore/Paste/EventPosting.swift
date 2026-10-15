import Carbon.HIToolbox
import CoreGraphics

public protocol EventPosting: Sendable {
    func postCommandV()
}

public struct CGEventPoster: EventPosting {
    // 仮想キーコードは物理位置なので、US/JIS 以外の配列では V にならない（README の既知の制限）
    static let vKeyCode = CGKeyCode(kVK_ANSI_V)

    public init() {}

    public func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        // 送出直後に押されたローカルのキー入力が ⌘V と混ざらないようにする
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: Self.vKeyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: Self.vKeyCode, keyDown: false) else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }
}
