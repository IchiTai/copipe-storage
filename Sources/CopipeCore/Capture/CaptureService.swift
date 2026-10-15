import AppKit

@MainActor
public final class CaptureService {
    public static let defaultInterval: Duration = .milliseconds(500)
    public static let unavailableReadsBeforeWarning = 3

    public private(set) var lastSeenChangeCount: Int
    public private(set) var lastReadResult: PasteboardReadResult?
    public private(set) var isReadBlocked = false
    public var onReadBlockedChange: ((Bool) -> Void)?

    private let pasteboard: NSPasteboard
    private let store: any HistoryStoring
    private let maxClipBytes: Int
    private let frontmostBundleID: @MainActor () -> String?
    private var ownWriteChangeCount: Int?
    private var consecutiveUnavailableReads = 0
    private var pollTask: Task<Void, Never>?

    public init(
        pasteboard: NSPasteboard = .general,
        store: any HistoryStoring,
        maxClipBytes: Int = Limits.defaultClipBytes,
        frontmostBundleID: @escaping @MainActor () -> String?
    ) {
        self.pasteboard = pasteboard
        self.store = store
        self.maxClipBytes = maxClipBytes
        self.frontmostBundleID = frontmostBundleID
        self.lastSeenChangeCount = pasteboard.changeCount
    }

    deinit {
        pollTask?.cancel()
    }

    public func start(interval: Duration = CaptureService.defaultInterval) {
        guard pollTask == nil else { return }
        updateReadBlocked()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                do {
                    try await Task.sleep(for: interval, tolerance: interval / 5)
                } catch {
                    return
                }
            }
        }
    }

    public func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    public func noteOwnWrite(changeCount: Int) {
        ownWriteChangeCount = changeCount
    }

    public func tick() async {
        let count = pasteboard.changeCount
        guard count != lastSeenChangeCount else { return }
        if count == ownWriteChangeCount {
            lastSeenChangeCount = count
            return
        }

        let result = PasteboardReader.read(
            from: pasteboard,
            expectedChangeCount: count,
            maxBytes: maxClipBytes,
            fallbackSourceBundleID: frontmostBundleID
        )
        lastReadResult = result
        if case .unavailable = result {
            // 読めなかった変化は changeCount を進めず、次の tick で読み直す
            consecutiveUnavailableReads += 1
        } else {
            lastSeenChangeCount = count
            consecutiveUnavailableReads = 0
        }
        updateReadBlocked()
        if case .capture(let capture) = result {
            await store.ingest(capture)
        }
    }

    private func updateReadBlocked() {
        let blocked = isAccessDenied || consecutiveUnavailableReads >= Self.unavailableReadsBeforeWarning
        guard blocked != isReadBlocked else { return }
        isReadBlocked = blocked
        onReadBlockedChange?(blocked)
    }

    private var isAccessDenied: Bool {
        if #available(macOS 15.4, *) {
            return pasteboard.accessBehavior == .alwaysDeny
        }
        return false
    }
}
