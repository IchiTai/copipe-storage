public struct Limits: Sendable, Equatable {
    public static let countRange = 100...3000
    public static let defaultCount = 1000
    public static let defaultClipBytes = 50 * 1024 * 1024

    public var maxClips: Int
    public var maxClipBytes: Int

    public init(maxClips: Int = Limits.defaultCount, maxClipBytes: Int = Limits.defaultClipBytes) {
        self.maxClips = min(max(maxClips, Limits.countRange.lowerBound), Limits.countRange.upperBound)
        self.maxClipBytes = maxClipBytes
    }
}
