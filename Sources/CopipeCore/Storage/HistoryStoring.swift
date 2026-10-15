import Foundation

public enum IngestResult: Sendable, Equatable {
    public enum RejectReason: Sendable, Equatable {
        case empty
        case tooLarge
        case writeFailed(String)
    }

    case inserted(Clip)
    case duplicateMovedToTop(Clip)
    case rejected(RejectReason)
}

public protocol HistoryStoring: Actor {
    func load() async
    func snapshot() -> [Clip]
    func updates() -> AsyncStream<[Clip]>
    @discardableResult
    func ingest(_ capture: Capture) async -> IngestResult
    func touch(_ id: Clip.ID) async
    func delete(_ id: Clip.ID) async
    func deleteAll() async
    func updateLimits(_ limits: Limits) async
    func loadRepresentations(_ id: Clip.ID) async throws -> [[Representation]]
    func loadPlainText(_ id: Clip.ID) async throws -> String?
    func flush() async
}
