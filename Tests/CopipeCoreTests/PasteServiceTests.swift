import AppKit
import Testing
@testable import CopipeCore

@Suite(.serialized) @MainActor struct PasteServiceTests {
    private func ingestSample(into world: PasteWorld) async throws -> Clip {
        let clip = try Fixtures.inserted(await world.store.ingest(Fixtures.capture(Fixtures.text("hello", rtf: true), Fixtures.text("second"))))
        await world.store.ingest(Fixtures.capture(Fixtures.text("newer")))
        return clip
    }

    @Test func copyOnlyWritesEverythingMovesClipToTopAndIsNotRecaptured() async throws {
        let world = await PasteWorld(permission: true)
        defer { world.cleanUp() }
        let clip = try await ingestSample(into: world)

        let outcome = await world.service.paste(clip, mode: .copyOnly, target: nil)

        #expect(outcome == .copiedOnly(.requested))
        #expect(world.poster.postCount == 0)
        let items = world.board.pasteboard.pasteboardItems ?? []
        #expect(items.count == 2)
        #expect(items[0].data(forType: .init(Fixtures.rtfType)) == Data("{\\rtf1 hello}".utf8))
        #expect(items[0].data(forType: .init(PasteboardMarkers.ownClipType)) == Data(clip.id.uuidString.utf8))
        #expect(items[1].string(forType: .init(Fixtures.plainType)) == "second")
        #expect(await world.store.snapshot().first?.id == clip.id)

        await world.capture.tick()
        #expect(await world.store.snapshot().count == 2)
    }

    @Test func plainTextWritesOnlyPlainText() async throws {
        let world = await PasteWorld(permission: true)
        defer { world.cleanUp() }
        let clip = try await ingestSample(into: world)

        let outcome = await world.service.paste(clip, mode: .plainText, target: nil)

        #expect(outcome == .pasted)
        #expect(world.poster.postCount == 1)
        let items = world.board.pasteboard.pasteboardItems ?? []
        #expect(items.count == 1)
        #expect(items[0].string(forType: .init(Fixtures.plainType)) == "hello\nsecond")
        #expect(items[0].data(forType: .init(Fixtures.rtfType)) == nil)
    }

    @Test func plainTextOfRTFOnlyClipIsConverted() async throws {
        let world = await PasteWorld(permission: true)
        defer { world.cleanUp() }
        let rtf = Representation(type: Fixtures.rtfType, data: Data("{\\rtf1\\ansi Hello {\\b bold}}".utf8))
        let clip = try Fixtures.inserted(await world.store.ingest(Fixtures.capture(CapturedItem(representations: [rtf]))))

        let outcome = await world.service.paste(clip, mode: .plainText, target: nil)

        #expect(outcome == .pasted)
        let items = world.board.pasteboard.pasteboardItems ?? []
        #expect(items.first?.string(forType: .init(Fixtures.plainType)) == "Hello bold")
        #expect(items.first?.data(forType: .init(Fixtures.rtfType)) == nil)
    }

    @Test func plainTextFallsBackToFullForClipsWithoutText() async throws {
        let world = await PasteWorld(permission: true)
        defer { world.cleanUp() }
        let clip = try Fixtures.inserted(await world.store.ingest(Fixtures.capture(Fixtures.image(width: 40, height: 20))))

        let outcome = await world.service.paste(clip, mode: .plainText, target: nil)

        #expect(outcome == .pasted)
        #expect(world.board.pasteboard.pasteboardItems?.first?.data(forType: .init("public.png")) != nil)
    }

    @Test func withoutPermissionItOnlyCopies() async throws {
        let world = await PasteWorld(permission: false)
        defer { world.cleanUp() }
        let clip = try await ingestSample(into: world)

        let outcome = await world.service.paste(clip, mode: .full, target: nil)

        #expect(outcome == .copiedOnly(.noPostEventPermission))
        #expect(world.poster.postCount == 0)
        #expect(world.board.pasteboard.pasteboardItems?.first?.data(forType: .init(Fixtures.rtfType)) != nil)
    }

    @Test func activeAppWithoutTargetCannotPaste() async throws {
        let world = await PasteWorld(permission: true, appActive: true)
        defer { world.cleanUp() }
        let clip = try await ingestSample(into: world)

        let outcome = await world.service.paste(clip, mode: .full, target: nil)

        #expect(outcome == .copiedOnly(.activationTimedOut))
        #expect(world.poster.postCount == 0)
    }

    @Test func missingDataIsReportedAsFailure() async throws {
        let world = await PasteWorld(permission: true)
        defer { world.cleanUp() }
        let clip = try await ingestSample(into: world)
        try FileManager.default.removeItem(at: world.temp.layout.clipDirectory(clip.id))

        #expect(await world.service.paste(clip, mode: .full, target: nil) == .failed)
        #expect(world.poster.postCount == 0)
    }
}
