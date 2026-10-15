import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ThumbnailMaker {
    public static let maxPixelSize = 256

    public struct Result: Sendable, Equatable {
        public var png: Data
        public var sourcePixelSize: PixelSize
    }

    public static func make(from data: Data, maxPixelSize: Int = ThumbnailMaker.maxPixelSize) -> Result? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0 else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        var width = (properties[kCGImagePropertyPixelWidth] as? Int) ?? thumbnail.width
        var height = (properties[kCGImagePropertyPixelHeight] as? Int) ?? thumbnail.height
        // サムネイルは EXIF の向きを適用して作るので、横向き保存（向き 5〜8）の画像は寸法も入れ替える
        if let orientation = properties[kCGImagePropertyOrientation] as? UInt32, (5...8).contains(orientation) {
            swap(&width, &height)
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, thumbnail, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return Result(png: output as Data, sourcePixelSize: PixelSize(width: width, height: height))
    }
}
