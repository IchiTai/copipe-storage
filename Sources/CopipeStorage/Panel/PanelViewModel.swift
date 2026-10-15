import AppKit
import CopipeCore
import Observation

@Observable
final class PanelViewModel {
    static let thumbnailCacheLimit = 200

    var filterText = "" {
        didSet { if filterText != oldValue { recomputeFiltered() } }
    }
    private(set) var clips: [Clip] = []
    private(set) var filteredClips: [Clip] = []
    var selectedID: Clip.ID?
    private(set) var focusRequestCount = 0

    var onActivate: ((Clip, PasteMode) -> Void)?
    var onClose: (() -> Void)?
    var openMenu: () -> Void = {}

    private let store: any HistoryStoring
    private let layout: StorageLayout
    @ObservationIgnored private var iconCache: [String: NSImage?] = [:]
    @ObservationIgnored private let thumbnailCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = PanelViewModel.thumbnailCacheLimit
        return cache
    }()
    @ObservationIgnored private var subscription: Task<Void, Never>?

    init(store: any HistoryStoring, layout: StorageLayout) {
        self.store = store
        self.layout = layout
    }

    func startObserving() {
        subscription = Task { [weak self, store] in
            for await clips in await store.updates() {
                guard let self else { return }
                self.clips = clips
                self.recomputeFiltered()
            }
        }
    }

    var selectedIndex: Int? {
        filteredClips.firstIndex { $0.id == selectedID }
    }

    func reset() {
        filterText = ""
        selectedID = filteredClips.first?.id
        focusRequestCount += 1
    }

    func moveSelection(by delta: Int) {
        guard !filteredClips.isEmpty else { return }
        let current = selectedIndex ?? -1
        let next = min(max(current + delta, 0), filteredClips.count - 1)
        selectedID = filteredClips[next].id
    }

    func activateSelected(mode: PasteMode) {
        guard let index = selectedIndex else { return }
        activate(index: index, mode: mode)
    }

    func activate(index: Int, mode: PasteMode) {
        guard filteredClips.indices.contains(index) else { return }
        onActivate?(filteredClips[index], mode)
    }

    func activate(id: Clip.ID, mode: PasteMode) {
        guard let clip = filteredClips.first(where: { $0.id == id }) else { return }
        selectedID = id
        onActivate?(clip, mode)
    }

    func deleteSelected() {
        guard let index = selectedIndex else { return }
        let id = filteredClips[index].id
        let nextIndex = index + 1 < filteredClips.count ? index + 1 : index - 1
        selectedID = filteredClips.indices.contains(nextIndex) ? filteredClips[nextIndex].id : nil
        Task { await store.delete(id) }
    }

    func primaryText(for clip: Clip) -> String {
        switch clip.kind {
        case .image:
            if !clip.preview.isEmpty { return clip.preview }
            if let size = clip.imagePixelSize {
                return String(format: L10n.string("panel.image_size"), size.width, size.height)
            }
            return L10n.string("panel.image")
        case .text, .file:
            return clip.preview
        }
    }

    func timeLabel(for clip: Clip) -> String {
        TimeLabel.string(for: clip.lastUsedAt)
    }

    func icon(for clip: Clip) -> NSImage? {
        guard let bundleID = clip.sourceBundleID else { return nil }
        if let cached = iconCache[bundleID] { return cached }
        let icon = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).map { NSWorkspace.shared.icon(forFile: $0.path) }
        iconCache[bundleID] = .some(icon)
        return icon
    }

    func thumbnail(for clip: Clip) -> NSImage? {
        guard clip.hasThumbnail else { return nil }
        let key = clip.id.uuidString as NSString
        if let cached = thumbnailCache.object(forKey: key) { return cached }
        guard let image = NSImage(contentsOf: layout.thumbnailURL(clip.id)) else { return nil }
        thumbnailCache.setObject(image, forKey: key)
        return image
    }

    private func recomputeFiltered() {
        let needle = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        if needle.isEmpty {
            filteredClips = clips
        } else {
            filteredClips = clips.filter { clip in
                clip.preview.localizedCaseInsensitiveContains(needle)
                    || (clip.fileNames ?? []).contains { $0.localizedCaseInsensitiveContains(needle) }
            }
        }
        if let selectedID, filteredClips.contains(where: { $0.id == selectedID }) { return }
        selectedID = filteredClips.first?.id
    }
}
