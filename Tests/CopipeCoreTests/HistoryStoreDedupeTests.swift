import Foundation
import Testing
@testable import CopipeCore

@Suite struct HistoryStoreDedupeTests {
    @Test func sameContentTwiceKeepsOneClipAtTop() async throws {
        let temp = TemporaryStore()
        defer { temp.cleanUp() }
        let clock = MutableClock(Date(timeIntervalSince1970: 2_000_000))
        let store = await temp.makeStore(now: { clock.now })

        let inserted = try Fixtures.inserted(await store.ingest(Fixtures.capture(Fixtures.text("hello", rtf: true))))
        await store.ingest(Fixtures.capture(Fixtures.text("other")))
        clock.advance(60)
        let second = await store.ingest(Fixtures.capture(Fixtures.text("hello", rtf: true), source: "com.apple.Terminal"))

        guard case .duplicateMovedToTop(let moved) = second else { Issue.record("expected duplicate, got \(second)"); return }
        #expect(moved.id == inserted.id)
        #expect(moved.lastUsedAt == clock.now)
        let clips = await store.snapshot()
        #expect(clips.count == 2)
        #expect(clips.first?.id == inserted.id)
        #expect(clips.first?.sourceBundleID == "com.apple.Safari")
    }

    @Test func formattingDifferenceIsNotADuplicate() async throws {
        let temp = TemporaryStore()
        defer { temp.cleanUp() }
        let store = await temp.makeStore()
        await store.ingest(Fixtures.capture(Fixtures.text("hello", rtf: true)))
        await store.ingest(Fixtures.capture(Fixtures.text("hello")))
        #expect(await store.snapshot().count == 2)
    }

    @Test func touchMovesClipToTop() async throws {
        let temp = TemporaryStore()
        defer { temp.cleanUp() }
        let clock = MutableClock(Date(timeIntervalSince1970: 3_000_000))
        let store = await temp.makeStore(now: { clock.now })
        let a = try Fixtures.inserted(await store.ingest(Fixtures.capture(Fixtures.text("a"), at: clock.now)))
        clock.advance(1)
        await store.ingest(Fixtures.capture(Fixtures.text("b"), at: clock.now))
        clock.advance(1)
        await store.touch(a.id)
        let clips = await store.snapshot()
        #expect(clips.map(\.preview) == ["a", "b"])
        #expect(clips[0].lastUsedAt == clock.now)
    }

    @Test func emptyCaptureIsRejected() async throws {
        let temp = TemporaryStore()
        defer { temp.cleanUp() }
        let store = await temp.makeStore()
        #expect(await store.ingest(Capture(items: [])) == .rejected(.empty))
        #expect(await store.snapshot().isEmpty)
    }
}
