import Foundation

public enum Kind: String, Codable, Sendable {
    case text
    case image
    case file
}

public struct PixelSize: Codable, Sendable, Equatable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

public struct Clip: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public var kind: Kind
    public var createdAt: Date
    public var lastUsedAt: Date
    public var sourceBundleID: String?
    public var preview: String
    public var contentHash: String
    public var hasThumbnail: Bool
    public var imagePixelSize: PixelSize?
    public var fileNames: [String]?

    public init(
        id: UUID = UUID(),
        kind: Kind,
        createdAt: Date,
        lastUsedAt: Date,
        sourceBundleID: String?,
        preview: String,
        contentHash: String,
        hasThumbnail: Bool = false,
        imagePixelSize: PixelSize? = nil,
        fileNames: [String]? = nil
    ) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.sourceBundleID = sourceBundleID
        self.preview = preview
        self.contentHash = contentHash
        self.hasThumbnail = hasThumbnail
        self.imagePixelSize = imagePixelSize
        self.fileNames = fileNames
    }

    // 同じ schemaVersion のまま増やしたフィールドは、無ければ既定値で読む（古い manifest を読めなくしない）
    private enum CodingKeys: String, CodingKey {
        case id, kind, createdAt, lastUsedAt, sourceBundleID, preview, contentHash, hasThumbnail, imagePixelSize, fileNames
        case legacyThumbnailPath = "thumbnailPath"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(Kind.self, forKey: .kind)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastUsedAt = try container.decode(Date.self, forKey: .lastUsedAt)
        sourceBundleID = try container.decodeIfPresent(String.self, forKey: .sourceBundleID)
        preview = try container.decode(String.self, forKey: .preview)
        contentHash = try container.decode(String.self, forKey: .contentHash)
        hasThumbnail = try container.decodeIfPresent(Bool.self, forKey: .hasThumbnail)
            ?? (container.decodeIfPresent(String.self, forKey: .legacyThumbnailPath) != nil)
        imagePixelSize = try container.decodeIfPresent(PixelSize.self, forKey: .imagePixelSize)
        fileNames = try container.decodeIfPresent([String].self, forKey: .fileNames)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastUsedAt, forKey: .lastUsedAt)
        try container.encodeIfPresent(sourceBundleID, forKey: .sourceBundleID)
        try container.encode(preview, forKey: .preview)
        try container.encode(contentHash, forKey: .contentHash)
        try container.encode(hasThumbnail, forKey: .hasThumbnail)
        try container.encodeIfPresent(imagePixelSize, forKey: .imagePixelSize)
        try container.encodeIfPresent(fileNames, forKey: .fileNames)
    }
}

public struct RepresentationRecord: Codable, Sendable, Equatable {
    public var type: String
    public var file: String

    public init(type: String, file: String) {
        self.type = type
        self.file = file
    }
}

public struct ClipManifest: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var clip: Clip
    public var items: [[RepresentationRecord]]

    public init(schemaVersion: Int = ClipManifest.currentSchemaVersion, clip: Clip, items: [[RepresentationRecord]]) {
        self.schemaVersion = schemaVersion
        self.clip = clip
        self.items = items
    }
}

public struct HistoryIndex: Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var clips: [Clip]

    public init(schemaVersion: Int = HistoryIndex.currentSchemaVersion, clips: [Clip]) {
        self.schemaVersion = schemaVersion
        self.clips = clips
    }
}
