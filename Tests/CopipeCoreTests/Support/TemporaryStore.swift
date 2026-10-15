import Foundation
@testable import CopipeCore

struct TemporaryStore {
    let root: URL
    let layout: StorageLayout

    init() {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("copipe-tests-\(UUID().uuidString)", isDirectory: true)
        layout = StorageLayout(root: root)
    }

    func makeStore(limits: Limits = Limits(), now: @escaping @Sendable () -> Date = { Date() }) async -> FileHistoryStore {
        let store = FileHistoryStore(layout: layout, limits: limits, now: now)
        await store.load()
        return store
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }
}
