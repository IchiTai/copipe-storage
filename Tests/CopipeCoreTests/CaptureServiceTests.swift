import AppKit
import Testing
@testable import CopipeCore

@Suite(.serialized) @MainActor struct CaptureServiceTests {
    @Test func readsEveryItemAndRepresentationInOrder() async {
        let board = PrivatePasteboard()
        defer { board.release() }
        let store = RecordingStore()
        let service = board.makeCapture(store: store)
        board.write([
            [Fixtures.plainType: Data("one".utf8), Fixtures.rtfType: Data("{\\rtf1 one}".utf8)],
            [Fixtures.plainType: Data("two".utf8)],
        ])

        await service.tick()

        let captures = await store.captures
        #expect(captures.count == 1)
        let items = captures.first?.items ?? []
        #expect(items.count == 2)
        // AppKit は対応する別形式（public.utf16-external-plain-text など）を項目へ自動で足すので、集合の一致ではなく包含で見る
        #expect(Set(items[0].types).isSuperset(of: [Fixtures.plainType, Fixtures.rtfType]))
        #expect(items[0].representations.first { $0.type == Fixtures.rtfType }?.data == Data("{\\rtf1 one}".utf8))
        #expect(items[1].types.contains(Fixtures.plainType))
        #expect(captures.first?.sourceBundleID == "com.example.fallback")
    }

    @Test func unchangedPasteboardIsNotReadAgain() async {
        let board = PrivatePasteboard()
        defer { board.release() }
        let store = RecordingStore()
        let service = board.makeCapture(store: store)
        board.write([[Fixtures.plainType: Data("same".utf8)]])

        await service.tick()
        await service.tick()

        #expect(await store.captures.count == 1)
    }

    @Test func concealedContentIsSkipped() async {
        let board = PrivatePasteboard()
        defer { board.release() }
        let store = RecordingStore()
        let service = board.makeCapture(store: store)
        board.write([[Fixtures.plainType: Data("secret".utf8), "org.nspasteboard.ConcealedType": Data()]])

        await service.tick()

        #expect(await store.captures.isEmpty)
        #expect(service.lastReadResult == .skippedMarker)
    }

    @Test func oversizedContentIsNotCaptured() async {
        let board = PrivatePasteboard()
        defer { board.release() }
        let store = RecordingStore()
        let service = board.makeCapture(store: store, maxClipBytes: 16)
        board.write([[Fixtures.plainType: Data(repeating: 0x41, count: 32)]])

        await service.tick()

        #expect(await store.captures.isEmpty)
        #expect(service.lastReadResult == .tooLarge)
    }

    @Test func declaredSourceWinsOverFallback() async {
        let board = PrivatePasteboard()
        defer { board.release() }
        let store = RecordingStore()
        let service = board.makeCapture(store: store)
        board.write([[Fixtures.plainType: Data("text".utf8), "org.nspasteboard.source": Data("com.example.declared".utf8)]])

        await service.tick()

        #expect(await store.captures.first?.sourceBundleID == "com.example.declared")
    }

    @Test func ownWriteIsIgnoredButLaterExternalWriteIsCaptured() async {
        let board = PrivatePasteboard()
        defer { board.release() }
        let store = RecordingStore()
        let service = board.makeCapture(store: store)
        let ownCount = board.write([[Fixtures.plainType: Data("ours".utf8)]])
        service.noteOwnWrite(changeCount: ownCount)

        await service.tick()
        #expect(await store.captures.isEmpty)

        board.write([[Fixtures.plainType: Data("theirs".utf8)]])
        await service.tick()
        #expect(await store.captures.count == 1)
    }

    @Test func stopCancelsPolling() async {
        let board = PrivatePasteboard()
        defer { board.release() }
        let store = RecordingStore()
        let service = board.makeCapture(store: store)
        service.start(interval: .milliseconds(10))
        service.stop()
        board.write([[Fixtures.plainType: Data("after stop".utf8)]])
        try? await Task.sleep(for: .milliseconds(50))
        #expect(await store.captures.isEmpty)
    }
}

@MainActor
private final class EmptyProvider: NSObject, NSPasteboardItemDataProvider {
    nonisolated func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {}
}

@Suite(.serialized) @MainActor struct CaptureServiceProviderTests {
    @Test func representationWithoutDataIsSkippedNotFatal() async {
        let board = PrivatePasteboard()
        defer { board.release() }
        let store = RecordingStore()
        let service = board.makeCapture(store: store)
        let provider = EmptyProvider()
        let item = NSPasteboardItem()
        item.setData(Data("text".utf8), forType: .init(Fixtures.plainType))
        item.setDataProvider(provider, forTypes: [.init("com.example.lazy")])
        board.pasteboard.clearContents()
        board.pasteboard.writeObjects([item])

        await service.tick()

        let captures = await store.captures
        #expect(captures.count == 1)
        let types = captures.first?.items.first?.types ?? []
        #expect(types.contains(Fixtures.plainType))
        #expect(!types.contains("com.example.lazy"))
    }
}
