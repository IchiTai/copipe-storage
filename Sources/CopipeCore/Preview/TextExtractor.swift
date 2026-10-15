import AppKit
import Foundation
import UniformTypeIdentifiers

public enum TextExtractor {
    public static let plainTextType = UTType.utf8PlainText.identifier
    public static let rtfType = UTType.rtf.identifier
    public static let htmlType = UTType.html.identifier
    public static let textTypes: Set<String> = [plainTextType, rtfType, htmlType]

    /// 各 item の文字を改行で連結する。文字の形式が 1 つも無ければ nil。
    /// byteLimit を与えると各形式の先頭だけを復号し、markupByteLimit を超える RTF/HTML は解釈しない（プレビュー用）
    public static func text(from items: [CapturedItem], byteLimit: Int? = nil, markupByteLimit: Int? = nil) -> String? {
        let parts = items.compactMap { text(from: $0.representations, byteLimit: byteLimit, markupByteLimit: markupByteLimit) }
        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }

    public static func hasText(_ items: [CapturedItem]) -> Bool {
        items.contains { $0.representations.contains { textTypes.contains($0.type) } }
    }

    static func text(from representations: [Representation], byteLimit: Int?, markupByteLimit: Int?) -> String? {
        if let plain = representations.first(where: { $0.type == plainTextType }) {
            return decodeUTF8(plain.data, byteLimit: byteLimit)
        }
        if let rtf = representations.first(where: { $0.type == rtfType }), withinLimit(rtf.data, markupByteLimit),
           let attributed = NSAttributedString(rtf: rtf.data, documentAttributes: nil) {
            return bounded(attributed.string, byteLimit)
        }
        if let html = representations.first(where: { $0.type == htmlType }), withinLimit(html.data, markupByteLimit),
           let string = String(data: html.data, encoding: .utf8) {
            return bounded(string.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression), byteLimit)
        }
        return nil
    }

    static func decodeUTF8(_ data: Data, byteLimit: Int?) -> String {
        guard let byteLimit, data.count > byteLimit else { return String(decoding: data, as: UTF8.self) }
        var text = String(decoding: data.prefix(byteLimit), as: UTF8.self)
        // 途中で切れた多バイト文字は置換文字になるので末尾から落とす
        while text.last == "\u{FFFD}" {
            text.removeLast()
        }
        return text
    }

    static func bounded(_ text: String, _ byteLimit: Int?) -> String {
        guard let byteLimit else { return text }
        return String(text.prefix(byteLimit))
    }

    static func withinLimit(_ data: Data, _ limit: Int?) -> Bool {
        guard let limit else { return true }
        return data.count <= limit
    }
}
