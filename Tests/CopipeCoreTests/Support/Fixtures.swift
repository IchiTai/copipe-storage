import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import CopipeCore

struct UnexpectedIngestResult: Error {
    let result: IngestResult
}

enum Fixtures {
    static let plainType = TextExtractor.plainTextType
    static let rtfType = TextExtractor.rtfType

    static func text(_ string: String, rtf: Bool = false) -> CapturedItem {
        var reps = [Representation(type: plainType, data: Data(string.utf8))]
        if rtf {
            reps.append(Representation(type: rtfType, data: Data("{\\rtf1 \(string)}".utf8)))
        }
        return CapturedItem(representations: reps)
    }

    static func file(_ path: String) -> CapturedItem {
        let url = URL(fileURLWithPath: path)
        return CapturedItem(representations: [Representation(type: PreviewBuilder.fileURLType, data: url.dataRepresentation)])
    }

    static func image(width: Int, height: Int) -> CapturedItem {
        CapturedItem(representations: [Representation(type: UTType.png.identifier, data: png(width: width, height: height))])
    }

    static func png(width: Int, height: Int) -> Data {
        encode(cgImage(width: width, height: height), as: .png, properties: nil)
    }

    static func jpeg(width: Int, height: Int, orientation: UInt32) -> Data {
        encode(cgImage(width: width, height: height), as: .jpeg, properties: [kCGImagePropertyOrientation: orientation])
    }

    static func capture(_ items: CapturedItem..., source: String? = "com.apple.Safari", at date: Date = Date(timeIntervalSince1970: 1_000_000)) -> Capture {
        Capture(items: items, sourceBundleID: source, capturedAt: date)
    }

    static func inserted(_ result: IngestResult, sourceLocation: SourceLocation = #_sourceLocation) throws -> Clip {
        if case .inserted(let clip) = result { return clip }
        Issue.record("expected .inserted, got \(result)", sourceLocation: sourceLocation)
        throw UnexpectedIngestResult(result: result)
    }

    private static func cgImage(width: Int, height: Int) -> CGImage {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    private static func encode(_ image: CGImage, as type: UTType, properties: [CFString: Any]?) -> Data {
        let output = NSMutableData()
        let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, properties as CFDictionary?)
        CGImageDestinationFinalize(destination)
        return output as Data
    }
}
