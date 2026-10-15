import Foundation

public struct StorageLayout: Sendable, Equatable {
    public static let thumbnailFileName = "thumbnail.png"
    public static let manifestFileName = "manifest.json"

    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public static func defaultLayout() -> StorageLayout {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return StorageLayout(root: base.appendingPathComponent(AppIdentity.bundleIdentifier, isDirectory: true))
    }

    public var indexURL: URL { root.appendingPathComponent("index.json") }
    public var clipsDirectory: URL { root.appendingPathComponent("clips", isDirectory: true) }

    public func clipDirectory(_ id: UUID) -> URL {
        clipsDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    public func temporaryClipDirectory(_ id: UUID) -> URL {
        clipsDirectory.appendingPathComponent(id.uuidString + ".tmp", isDirectory: true)
    }

    public func manifestURL(_ id: UUID) -> URL {
        clipDirectory(id).appendingPathComponent(Self.manifestFileName)
    }

    public func thumbnailURL(_ id: UUID) -> URL {
        clipDirectory(id).appendingPathComponent(Self.thumbnailFileName)
    }

    public static func representationFileName(item: Int, representation: Int) -> String {
        "\(item)-\(representation).bin"
    }

    public func indexBackupURL(reason: String, now: Date = Date()) -> URL {
        let stamp = ISO8601DateFormatter().string(from: now).replacingOccurrences(of: ":", with: "-")
        return root.appendingPathComponent("index.json.\(reason)-\(stamp)")
    }
}
