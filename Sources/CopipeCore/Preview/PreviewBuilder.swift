import Foundation
import UniformTypeIdentifiers

public enum PreviewBuilder {
    public static let previewLimit = 200
    public static let previewByteLimit = 8 * 1024
    public static let markupByteLimit = 256 * 1024
    public static let fileURLType = UTType.fileURL.identifier
    static let imageTypePriority = [UTType.png, .jpeg, .heic, .tiff, .pdf].map(\.identifier)

    public struct Summary: Sendable, Equatable {
        public var kind: Kind
        public var preview: String
        public var fileNames: [String]?
        public var thumbnail: ThumbnailMaker.Result?
    }

    public static func summarize(_ capture: Capture) -> Summary {
        switch kind(of: capture) {
        case .file:
            let names = fileNames(in: capture)
            return Summary(kind: .file, preview: truncate(names.joined(separator: ", ")), fileNames: names, thumbnail: nil)
        case .image:
            let thumbnail = imageData(in: capture).flatMap { ThumbnailMaker.make(from: $0) }
            let preview = TextExtractor.hasText(capture.items) ? textPreview(of: capture) : ""
            return Summary(kind: .image, preview: preview, fileNames: nil, thumbnail: thumbnail)
        case .text:
            return Summary(kind: .text, preview: textPreview(of: capture), fileNames: nil, thumbnail: nil)
        }
    }

    public static func kind(of capture: Capture) -> Kind {
        let types = capture.allTypes
        if types.contains(fileURLType) { return .file }
        if types.contains(where: isImageType) { return .image }
        return .text
    }

    public static func textPreview(of capture: Capture) -> String {
        let text = TextExtractor.text(from: capture.items, byteLimit: previewByteLimit, markupByteLimit: markupByteLimit)
            ?? capture.allTypes.sorted().joined(separator: ", ")
        return truncate(collapseWhitespace(text))
    }

    public static func fileNames(in capture: Capture) -> [String] {
        var names: [String] = []
        for item in capture.items {
            for representation in item.representations where representation.type == fileURLType {
                guard let url = URL(dataRepresentation: representation.data, relativeTo: nil) else { continue }
                let resolved = (url as NSURL).filePathURL ?? url
                names.append(resolved.lastPathComponent)
            }
        }
        return names
    }

    static func isImageType(_ type: String) -> Bool {
        UTType(type)?.conforms(to: .image) == true
    }

    static func imageData(in capture: Capture) -> Data? {
        for type in imageTypePriority {
            for item in capture.items {
                if let representation = item.representations.first(where: { $0.type == type }) {
                    return representation.data
                }
            }
        }
        for item in capture.items {
            if let representation = item.representations.first(where: { isImageType($0.type) }) {
                return representation.data
            }
        }
        return nil
    }

    static func collapseWhitespace(_ text: String) -> String {
        text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func truncate(_ text: String) -> String {
        String(text.prefix(previewLimit))
    }
}
