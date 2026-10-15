import AppKit

public enum PasteboardWriter {
    @MainActor
    public static func write(_ items: [[Representation]], clipID: UUID, to pasteboard: NSPasteboard) -> Int {
        pasteboard.clearContents()
        var pasteboardItems = items.map { representations -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for representation in representations {
                item.setData(representation.data, forType: NSPasteboard.PasteboardType(representation.type))
            }
            return item
        }
        if pasteboardItems.isEmpty {
            pasteboardItems.append(NSPasteboardItem())
        }
        pasteboardItems[0].setData(Data(clipID.uuidString.utf8), forType: NSPasteboard.PasteboardType(PasteboardMarkers.ownClipType))
        pasteboard.writeObjects(pasteboardItems)
        return pasteboard.changeCount
    }
}
