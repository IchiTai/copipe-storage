import AppKit
@testable import CopipeCore

@MainActor
struct PrivatePasteboard {
    let pasteboard: NSPasteboard

    init() {
        pasteboard = NSPasteboard.withUniqueName()
    }

    func makeCapture(store: any HistoryStoring, maxClipBytes: Int = Limits.defaultClipBytes, fallbackSource: String? = "com.example.fallback") -> CaptureService {
        CaptureService(pasteboard: pasteboard, store: store, maxClipBytes: maxClipBytes, frontmostBundleID: { fallbackSource })
    }

    @discardableResult
    func write(_ items: [[String: Data]]) -> Int {
        pasteboard.clearContents()
        let pasteboardItems = items.map { entries -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entries.sorted(by: { $0.key < $1.key }) {
                item.setData(data, forType: NSPasteboard.PasteboardType(type))
            }
            return item
        }
        pasteboard.writeObjects(pasteboardItems)
        return pasteboard.changeCount
    }

    func release() {
        pasteboard.releaseGlobally()
    }
}
