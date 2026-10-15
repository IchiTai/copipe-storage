import Foundation
@testable import CopipeCore

final class FakeEventPoster: EventPosting, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var postCount: Int { lock.withLock { count } }

    func postCommandV() {
        lock.withLock { count += 1 }
    }
}
