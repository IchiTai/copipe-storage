import AppKit
import Foundation
@testable import CopipeCore

@MainActor
struct PasteWorld {
    let temp: TemporaryStore
    let board: PrivatePasteboard
    let store: FileHistoryStore
    let capture: CaptureService
    let service: PasteService
    let poster: FakeEventPoster

    init(permission: Bool, appActive: Bool = false) async {
        temp = TemporaryStore()
        board = PrivatePasteboard()
        store = await temp.makeStore()
        capture = CaptureService(pasteboard: board.pasteboard, store: store, frontmostBundleID: { nil })
        poster = FakeEventPoster()
        service = PasteService(pasteboard: board.pasteboard, store: store, capture: capture, poster: poster,
                               hasPermission: { permission }, isAppActive: { appActive })
    }

    func cleanUp() {
        temp.cleanUp()
        board.release()
    }
}
