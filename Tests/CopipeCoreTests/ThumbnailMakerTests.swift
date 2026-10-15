import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import CopipeCore

@Suite struct ThumbnailMakerTests {
    @Test func longEdgeIsLimitedTo256() throws {
        let result = try #require(ThumbnailMaker.make(from: Fixtures.png(width: 1000, height: 500)))
        #expect(result.sourcePixelSize == PixelSize(width: 1000, height: 500))
        let source = try #require(CGImageSourceCreateWithData(result.png as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 256)
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == 128)
    }

    @Test func rotatedExifOrientationSwapsTheReportedSize() throws {
        let result = try #require(ThumbnailMaker.make(from: Fixtures.jpeg(width: 400, height: 200, orientation: 6)))
        #expect(result.sourcePixelSize == PixelSize(width: 200, height: 400))
        let source = try #require(CGImageSourceCreateWithData(result.png as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 128)
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == 256)
    }

    @Test func garbageIsNotAnImage() {
        #expect(ThumbnailMaker.make(from: Data("not an image".utf8)) == nil)
    }
}
