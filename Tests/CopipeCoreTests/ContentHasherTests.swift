import Foundation
import Testing
@testable import CopipeCore

@Suite struct ContentHasherTests {
    @Test func sameInputGivesSameHexDigest() {
        let a = ContentHasher.hash(Fixtures.capture(Fixtures.text("hello", rtf: true)))
        let b = ContentHasher.hash(Fixtures.capture(Fixtures.text("hello", rtf: true)))
        #expect(a == b)
        #expect(a.count == 64)
        #expect(a.allSatisfy { $0.isHexDigit })
    }

    @Test func representationOrderDoesNotMatter() {
        let item = Fixtures.text("hello", rtf: true)
        let reversed = CapturedItem(representations: item.representations.reversed())
        #expect(ContentHasher.hash(Fixtures.capture(item)) == ContentHasher.hash(Fixtures.capture(reversed)))
    }

    @Test func itemOrderMatters() {
        let a = Fixtures.capture(Fixtures.text("one"), Fixtures.text("two"))
        let b = Fixtures.capture(Fixtures.text("two"), Fixtures.text("one"))
        #expect(ContentHasher.hash(a) != ContentHasher.hash(b))
    }

    @Test func formattingMakesADifferentClip() {
        #expect(ContentHasher.hash(Fixtures.capture(Fixtures.text("hello"))) != ContentHasher.hash(Fixtures.capture(Fixtures.text("hello", rtf: true))))
    }

    @Test func metadataTypesAreIgnored() {
        let plain = Fixtures.text("hello")
        var withSource = plain
        withSource.representations.append(Representation(type: PasteboardMarkers.sourceType, data: Data("com.apple.Safari".utf8)))
        withSource.representations.append(Representation(type: PasteboardMarkers.ownClipType, data: Data("id".utf8)))
        #expect(ContentHasher.hash(Fixtures.capture(plain)) == ContentHasher.hash(Fixtures.capture(withSource)))
    }

    @Test func lengthPrefixSeparatesTypeFromData() {
        let a = Capture(items: [CapturedItem(representations: [Representation(type: "ab", data: Data("c".utf8))])])
        let b = Capture(items: [CapturedItem(representations: [Representation(type: "a", data: Data("bc".utf8))])])
        #expect(ContentHasher.hash(a) != ContentHasher.hash(b))
    }
}
