import CryptoKit
import Foundation

public enum ContentHasher {
    public static func hash(_ capture: Capture) -> String {
        var hasher = SHA256()
        for item in capture.items {
            hasher.update(data: Data("I".utf8))
            let representations = item.representations
                .filter { !PasteboardMarkers.isMetadataType($0.type) }
                .sorted { Array($0.type.utf8).lexicographicallyPrecedes(Array($1.type.utf8)) }
            for representation in representations {
                hasher.update(data: Data(representation.type.utf8))
                hasher.update(data: Data([0]))
                // 長さを入れないと、型名とデータの境界が違う 2 つの入力が同じ列に潰れ得る
                withUnsafeBytes(of: UInt64(representation.data.count).littleEndian) { hasher.update(bufferPointer: $0) }
                hasher.update(data: representation.data)
            }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
