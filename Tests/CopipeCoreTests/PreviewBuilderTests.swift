import Foundation
import Testing
import UniformTypeIdentifiers
@testable import CopipeCore

@Suite struct PreviewBuilderTests {
    @Test func collapsesWhitespaceAndTruncates() {
        let long = String(repeating: "あ", count: 300)
        let summary = PreviewBuilder.summarize(Fixtures.capture(Fixtures.text("  line one\n\n   line\ttwo  ")))
        #expect(summary.kind == .text)
        #expect(summary.preview == "line one line two")
        #expect(PreviewBuilder.summarize(Fixtures.capture(Fixtures.text(long))).preview.count == 200)
    }

    @Test func rtfOnlyFallsBackToPlainText() {
        let item = CapturedItem(representations: [Representation(type: Fixtures.rtfType, data: Data("{\\rtf1\\ansi Hello {\\b bold} world}".utf8))])
        #expect(PreviewBuilder.summarize(Fixtures.capture(item)).preview == "Hello bold world")
    }

    @Test func fileURLsBecomeFileNames() {
        let summary = PreviewBuilder.summarize(Fixtures.capture(Fixtures.file("/tmp/report.pdf"), Fixtures.file("/tmp/photo.jpg")))
        #expect(summary.kind == .file)
        #expect(summary.fileNames == ["report.pdf", "photo.jpg"])
        #expect(summary.preview == "report.pdf, photo.jpg")
    }

    @Test func imagesGetThumbnails() {
        let summary = PreviewBuilder.summarize(Fixtures.capture(Fixtures.image(width: 1000, height: 500)))
        #expect(summary.kind == .image)
        #expect(summary.preview == "")
        #expect(summary.thumbnail?.sourcePixelSize == PixelSize(width: 1000, height: 500))
    }

    @Test func imageWithTextKeepsThumbnailAndPreview() {
        var item = Fixtures.image(width: 300, height: 120)
        item.representations.append(Representation(type: Fixtures.plainType, data: Data("Quarterly revenue".utf8)))
        let summary = PreviewBuilder.summarize(Fixtures.capture(item))
        #expect(summary.kind == .image)
        #expect(summary.preview == "Quarterly revenue")
        #expect(summary.thumbnail != nil)
    }

    @Test func hugeTextIsPreviewedFromItsHeadQuickly() {
        let head = "Head of the clip. "
        let huge = head + String(repeating: "x", count: 20 * 1024 * 1024)
        let started = ContinuousClock.now
        let summary = PreviewBuilder.summarize(Fixtures.capture(Fixtures.text(huge)))
        let elapsed = ContinuousClock.now - started
        #expect(summary.preview.hasPrefix("Head of the clip. xxx"))
        #expect(summary.preview.count == 200)
        #expect(elapsed < .seconds(1))
    }

    @Test func multiByteBoundaryAtByteLimitIsDropped() {
        let text = String(repeating: "あ", count: 4000)
        let preview = PreviewBuilder.textPreview(of: Fixtures.capture(Fixtures.text(text)))
        #expect(!preview.contains("\u{FFFD}"))
        #expect(preview.count == 200)
    }
}
