import Foundation
import Testing
@testable import CopipeCore

@Suite struct PersistenceTests {
    @Test func clipsSurviveReload() async throws {
        let temp = TemporaryStore()
        defer { temp.cleanUp() }
        let store = await temp.makeStore()
        let capture = Fixtures.capture(Fixtures.text("hello", rtf: true), Fixtures.text("second"))
        let clip = try Fixtures.inserted(await store.ingest(capture))
        await store.ingest(Fixtures.capture(Fixtures.image(width: 640, height: 320)))
        await store.flush()

        let reloaded = await temp.makeStore()
        let clips = await reloaded.snapshot()
        #expect(clips.count == 2)
        #expect(clips.map(\.id).contains(clip.id))
        let representations = try await reloaded.loadRepresentations(clip.id)
        #expect(representations == capture.items.map(\.representations))
        #expect(try await reloaded.loadPlainText(clip.id) == "hello\nsecond")
        let image = clips.first { $0.kind == .image }
        #expect(image?.imagePixelSize == PixelSize(width: 640, height: 320))
        #expect(image?.hasThumbnail == true)
    }

    @Test func unflushedClipSurvivesReload() async throws {
        let temp = TemporaryStore()
        defer { temp.cleanUp() }
        let store = await temp.makeStore()
        _ = try Fixtures.inserted(await store.ingest(Fixtures.capture(Fixtures.text("flushed"))))
        await store.flush()
        let late = try Fixtures.inserted(await store.ingest(Fixtures.capture(Fixtures.text("not yet in the index"))))

        let reloaded = await temp.makeStore()
        let clips = await reloaded.snapshot()
        #expect(clips.map(\.id).contains(late.id))
        #expect(FileManager.default.fileExists(atPath: temp.layout.clipDirectory(late.id).path))
    }

    @Test func corruptIndexIsBackedUpAndRebuiltFromManifests() async throws {
        let temp = TemporaryStore()
        defer { temp.cleanUp() }
        let store = await temp.makeStore()
        let clip = try Fixtures.inserted(await store.ingest(Fixtures.capture(Fixtures.text("keep me"))))
        await store.flush()
        try Data("{ not json".utf8).write(to: temp.layout.indexURL)

        let reloaded = await temp.makeStore()
        let clips = await reloaded.snapshot()
        #expect(clips.map(\.id) == [clip.id])
        #expect(clips.first?.preview == "keep me")
        let backups = try FileManager.default.contentsOfDirectory(atPath: temp.root.path).filter { $0.hasPrefix("index.json.corrupt-") }
        #expect(backups.count == 1)
    }

    @Test func corruptIndexWithExistingBackupStillLoadsEverything() async throws {
        let temp = TemporaryStore()
        defer { temp.cleanUp() }
        let fixed = Date(timeIntervalSince1970: 6_000_000)
        let store = await temp.makeStore(now: { fixed })
        let clip = try Fixtures.inserted(await store.ingest(Fixtures.capture(Fixtures.text("keep me"))))
        await store.flush()
        try Data("{ not json".utf8).write(to: temp.layout.indexURL)
        try Data("old backup".utf8).write(to: temp.layout.indexBackupURL(reason: "corrupt", now: fixed))

        let reloaded = await temp.makeStore(now: { fixed })
        #expect(await reloaded.snapshot().map(\.id) == [clip.id])
        await reloaded.ingest(Fixtures.capture(Fixtures.text("after")))
        await reloaded.flush()
        let again = await temp.makeStore(now: { fixed })
        #expect(await again.snapshot().count == 2)
    }

    @Test func newerSchemaClipDirectoryIsLeftAlone() async throws {
        let temp = TemporaryStore()
        defer { temp.cleanUp() }
        let store = await temp.makeStore()
        let clip = try Fixtures.inserted(await store.ingest(Fixtures.capture(Fixtures.text("current"))))
        await store.flush()
        let newer = UUID()
        let directory = temp.layout.clipDirectory(newer)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{\"schemaVersion\":99,\"somethingNew\":true}".utf8).write(to: temp.layout.manifestURL(newer))

        let reloaded = await temp.makeStore()
        #expect(await reloaded.snapshot().map(\.id) == [clip.id])
        #expect(FileManager.default.fileExists(atPath: directory.path))
    }

    @Test func legacyManifestWithoutHasThumbnailIsStillReadable() async throws {
        let temp = TemporaryStore()
        defer { temp.cleanUp() }
        _ = await temp.makeStore()
        let id = UUID()
        let directory = temp.layout.clipDirectory(id)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("legacy".utf8).write(to: directory.appendingPathComponent("0-0.bin"))
        let legacy = """
        {"schemaVersion":1,"clip":{"id":"\(id.uuidString)","kind":"image","createdAt":"2026-10-15T11:51:36Z","lastUsedAt":"2026-10-15T11:51:36Z",
         "preview":"","byteCount":6,"contentHash":"abc","itemCount":1,"thumbnailPath":"thumbnail.png","imagePixelSize":{"width":8,"height":4}},
         "items":[[{"type":"public.png","file":"0-0.bin","byteCount":6}]]}
        """
        try Data(legacy.utf8).write(to: temp.layout.manifestURL(id))

        let reloaded = await temp.makeStore()
        let clip = try #require(await reloaded.snapshot().first { $0.id == id })
        #expect(clip.hasThumbnail)
        #expect(clip.imagePixelSize == PixelSize(width: 8, height: 4))
    }

    @Test func undecodableManifestIsKeptOnDisk() async throws {
        let temp = TemporaryStore()
        defer { temp.cleanUp() }
        _ = await temp.makeStore()
        let id = UUID()
        let directory = temp.layout.clipDirectory(id)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{\"schemaVersion\":1,\"clip\":{\"unexpected\":true},\"items\":[]}".utf8).write(to: temp.layout.manifestURL(id))

        let reloaded = await temp.makeStore()
        #expect(await reloaded.snapshot().isEmpty)
        #expect(FileManager.default.fileExists(atPath: directory.path))
    }

    @Test func temporaryAndBrokenDirectoriesAreRemovedOnLoad() async throws {
        let temp = TemporaryStore()
        defer { temp.cleanUp() }
        let store = await temp.makeStore()
        let clip = try Fixtures.inserted(await store.ingest(Fixtures.capture(Fixtures.text("keep me"))))
        let broken = try Fixtures.inserted(await store.ingest(Fixtures.capture(Fixtures.text("broken"))))
        await store.flush()
        let tmp = temp.layout.clipsDirectory.appendingPathComponent("leftover.tmp", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        try FileManager.default.removeItem(at: temp.layout.clipDirectory(broken.id).appendingPathComponent("0-0.bin"))

        let reloaded = await temp.makeStore()
        #expect(await reloaded.snapshot().map(\.id) == [clip.id])
        #expect(!FileManager.default.fileExists(atPath: tmp.path))
        #expect(!FileManager.default.fileExists(atPath: temp.layout.clipDirectory(broken.id).path))
    }

    @Test func deleteAndDeleteAllRemoveDirectories() async throws {
        let temp = TemporaryStore()
        defer { temp.cleanUp() }
        let store = await temp.makeStore()
        let a = try Fixtures.inserted(await store.ingest(Fixtures.capture(Fixtures.text("a"))))
        let b = try Fixtures.inserted(await store.ingest(Fixtures.capture(Fixtures.text("b"))))
        await store.delete(a.id)
        #expect(await store.snapshot().map(\.id) == [b.id])
        #expect(!FileManager.default.fileExists(atPath: temp.layout.clipDirectory(a.id).path))
        await store.deleteAll()
        #expect(await store.snapshot().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: temp.layout.clipDirectory(b.id).path))
    }

    @Test func updatesStreamEmitsOnChange() async throws {
        let temp = TemporaryStore()
        defer { temp.cleanUp() }
        let store = await temp.makeStore()
        let stream = await store.updates()
        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next()?.isEmpty == true)
        await store.ingest(Fixtures.capture(Fixtures.text("a")))
        #expect(await iterator.next()?.map(\.preview) == ["a"])
    }
}
