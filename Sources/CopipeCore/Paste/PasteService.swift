import AppKit

@MainActor
public final class PasteService {
    public static let settleDelay: Duration = .milliseconds(50)

    private let pasteboard: NSPasteboard
    private let store: any HistoryStoring
    private let capture: CaptureService
    private let poster: any EventPosting
    private let hasPermission: @MainActor () -> Bool
    private let isAppActive: @MainActor () -> Bool

    public init(
        pasteboard: NSPasteboard = .general,
        store: any HistoryStoring,
        capture: CaptureService,
        poster: any EventPosting = CGEventPoster(),
        hasPermission: @escaping @MainActor () -> Bool = { PostEventPermission.isGranted },
        isAppActive: @escaping @MainActor () -> Bool = { NSApp.isActive }
    ) {
        self.pasteboard = pasteboard
        self.store = store
        self.capture = capture
        self.poster = poster
        self.hasPermission = hasPermission
        self.isAppActive = isAppActive
    }

    public func paste(_ clip: Clip, mode: PasteMode, target: NSRunningApplication?) async -> PasteOutcome {
        let items: [[Representation]]
        do {
            switch mode {
            case .plainText:
                if let text = try await store.loadPlainText(clip.id) {
                    items = [[Representation(type: TextExtractor.plainTextType, data: Data(text.utf8))]]
                } else {
                    items = try await store.loadRepresentations(clip.id)
                }
            case .full, .copyOnly:
                items = try await store.loadRepresentations(clip.id)
            }
        } catch {
            return .failed
        }

        let changeCount = PasteboardWriter.write(items, clipID: clip.id, to: pasteboard)
        capture.noteOwnWrite(changeCount: changeCount)
        await store.touch(clip.id)

        if mode == .copyOnly { return .copiedOnly(.requested) }
        guard hasPermission() else { return .copiedOnly(.noPostEventPermission) }
        if let target, target.isTerminated { return .copiedOnly(.targetTerminated) }
        if isAppActive() {
            guard let target, await TargetActivator.activate(target) else { return .copiedOnly(.activationTimedOut) }
        }
        do {
            try await Task.sleep(for: Self.settleDelay)
        } catch {
            return .copiedOnly(.requested)
        }
        poster.postCommandV()
        return .pasted
    }
}
