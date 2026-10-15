import Foundation
import Testing
@testable import CopipeCore

@Suite struct TextExtractorTests {
    @Test func plainTextWins() {
        let items = [Fixtures.text("plain", rtf: true)]
        #expect(TextExtractor.text(from: items) == "plain")
    }

    @Test func rtfOnlyIsConvertedForPlainPaste() {
        let rtf = Representation(type: Fixtures.rtfType, data: Data("{\\rtf1\\ansi Hello {\\b bold}}".utf8))
        #expect(TextExtractor.text(from: [CapturedItem(representations: [rtf])]) == "Hello bold")
    }

    @Test func htmlOnlyIsStripped() {
        let html = Representation(type: TextExtractor.htmlType, data: Data("<p>Hello <b>html</b></p>".utf8))
        #expect(TextExtractor.text(from: [CapturedItem(representations: [html])])?.trimmingCharacters(in: .whitespaces) == "Hello  html")
    }

    @Test func imagesHaveNoText() {
        #expect(TextExtractor.text(from: [Fixtures.image(width: 4, height: 4)]) == nil)
        #expect(!TextExtractor.hasText([Fixtures.image(width: 4, height: 4)]))
    }

    @Test func markupOverTheLimitIsNotParsedForPreviews() {
        let html = Representation(type: TextExtractor.htmlType, data: Data(("<p>" + String(repeating: "a", count: 10)).utf8))
        #expect(TextExtractor.text(from: [CapturedItem(representations: [html])], byteLimit: 8, markupByteLimit: 4) == nil)
    }
}
