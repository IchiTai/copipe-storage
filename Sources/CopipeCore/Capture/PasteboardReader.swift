import AppKit

public enum PasteboardReadResult: Sendable, Equatable {
    case capture(Capture)
    case unavailable
    case empty
    case skippedMarker
    case tooLarge
    case stale
}

public enum PasteboardReader {
    @MainActor
    public static func read(
        from pasteboard: NSPasteboard,
        expectedChangeCount: Int,
        maxBytes: Int,
        fallbackSourceBundleID: () -> String?
    ) -> PasteboardReadResult {
        guard let items = pasteboard.pasteboardItems else { return .unavailable }
        guard !items.isEmpty else { return .empty }

        let itemTypes = items.flatMap { $0.types.map(\.rawValue) }
        let pasteboardTypes = pasteboard.types?.map(\.rawValue) ?? []
        if PasteboardMarkers.shouldSkip(types: itemTypes + pasteboardTypes) { return .skippedMarker }

        var captured: [CapturedItem] = []
        var total = 0
        for item in items {
            var representations: [Representation] = []
            for type in item.types {
                guard let data = item.data(forType: type) else {
                    // 所有者が変わると項目全体が stale になり nil を返す。changeCount が同じなら
                    // その形式だけ提供元が出せなかった（遅延提供の失敗など）ので、飛ばして残りを読む
                    if pasteboard.changeCount != expectedChangeCount { return .stale }
                    continue
                }
                total += data.count
                if total > maxBytes { return .tooLarge }
                representations.append(Representation(type: type.rawValue, data: data))
            }
            captured.append(CapturedItem(representations: representations))
        }
        guard pasteboard.changeCount == expectedChangeCount else { return .stale }
        guard total > 0 else { return .empty }

        let source = declaredSource(in: captured) ?? fallbackSourceBundleID()
        return .capture(Capture(items: captured, sourceBundleID: source, capturedAt: Date()))
    }

    static func declaredSource(in items: [CapturedItem]) -> String? {
        for item in items {
            for representation in item.representations where representation.type == PasteboardMarkers.sourceType {
                if let string = String(data: representation.data, encoding: .utf8), !string.isEmpty {
                    return string
                }
            }
        }
        return nil
    }
}
