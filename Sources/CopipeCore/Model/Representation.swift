import Foundation

public struct Representation: Sendable, Hashable, Codable {
    public let type: String
    public let data: Data

    public init(type: String, data: Data) {
        self.type = type
        self.data = data
    }
}

public struct CapturedItem: Sendable, Hashable {
    public var representations: [Representation]

    public init(representations: [Representation]) {
        self.representations = representations
    }

    public var byteCount: Int {
        representations.reduce(0) { $0 + $1.data.count }
    }

    public var types: [String] {
        representations.map(\.type)
    }
}

public struct Capture: Sendable, Equatable {
    public var items: [CapturedItem]
    public var sourceBundleID: String?
    public var capturedAt: Date

    public init(items: [CapturedItem], sourceBundleID: String? = nil, capturedAt: Date = Date()) {
        self.items = items
        self.sourceBundleID = sourceBundleID
        self.capturedAt = capturedAt
    }

    public var byteCount: Int {
        items.reduce(0) { $0 + $1.byteCount }
    }

    public var allTypes: Set<String> {
        Set(items.flatMap(\.types))
    }
}
