import Foundation
import Testing
@testable import CopipeCore

@Suite struct HistoryStoreLimitsTests {
    @Test func countLimitPrunesLeastRecentlyUsed() async throws {
        let temp = TemporaryStore()
        defer { temp.cleanUp() }
        let clock = MutableClock(Date(timeIntervalSince1970: 4_000_000))
        let store = await temp.makeStore(limits: Limits(maxClips: 100), now: { clock.now })
        var ids: [UUID] = []
        for i in 0..<100 {
            clock.advance(1)
            ids.append(try Fixtures.inserted(await store.ingest(Fixtures.capture(Fixtures.text("clip \(i)"), at: clock.now))).id)
        }
        clock.advance(1)
        await store.touch(ids[0])
        clock.advance(1)
        await store.ingest(Fixtures.capture(Fixtures.text("clip 100"), at: clock.now))

        let clips = await store.snapshot()
        #expect(clips.count == 100)
        #expect(clips.contains { $0.id == ids[0] })
        #expect(!clips.contains { $0.id == ids[1] })
        #expect(!FileManager.default.fileExists(atPath: temp.layout.clipDirectory(ids[1]).path))
        #expect(FileManager.default.fileExists(atPath: temp.layout.clipDirectory(ids[0]).path))
    }

    @Test func oversizedCaptureIsRejected() async throws {
        let temp = TemporaryStore()
        defer { temp.cleanUp() }
        let store = await temp.makeStore(limits: Limits(maxClipBytes: 1024))
        #expect(await store.ingest(Fixtures.capture(Fixtures.text(String(repeating: "A", count: 1025)))) == .rejected(.tooLarge))
        _ = try Fixtures.inserted(await store.ingest(Fixtures.capture(Fixtures.text(String(repeating: "A", count: 1024)))))
    }

    @Test func loweringTheLimitPrunesImmediately() async throws {
        let temp = TemporaryStore()
        defer { temp.cleanUp() }
        let clock = MutableClock(Date(timeIntervalSince1970: 5_000_000))
        let store = await temp.makeStore(limits: Limits(maxClips: 200), now: { clock.now })
        for i in 0..<150 {
            clock.advance(1)
            await store.ingest(Fixtures.capture(Fixtures.text("clip \(i)"), at: clock.now))
        }
        await store.updateLimits(Limits(maxClips: 100))
        let clips = await store.snapshot()
        #expect(clips.count == 100)
        #expect(clips.first?.preview == "clip 149")
        #expect(clips.last?.preview == "clip 50")
    }
}
