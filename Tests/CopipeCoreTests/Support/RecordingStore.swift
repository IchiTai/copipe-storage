import Foundation
@testable import CopipeCore

actor RecordingStore: HistoryStoring {
    private(set) var captures: [Capture] = []
    private(set) var touched: [Clip.ID] = []

    func load() async {}
    func snapshot() -> [Clip] { [] }
    func updates() -> AsyncStream<[Clip]> { AsyncStream { $0.finish() } }

    @discardableResult
    func ingest(_ capture: Capture) async -> IngestResult {
        captures.append(capture)
        return .rejected(.empty)
    }

    func touch(_ id: Clip.ID) async { touched.append(id) }
    func delete(_ id: Clip.ID) async {}
    func deleteAll() async {}
    func updateLimits(_ limits: Limits) async {}
    func loadRepresentations(_ id: Clip.ID) async throws -> [[Representation]] { [] }
    func loadPlainText(_ id: Clip.ID) async throws -> String? { nil }
    func flush() async {}
}
