import Foundation

public actor FileHistoryStore: HistoryStoring {
    public static let indexSaveDelay: Duration = .milliseconds(250)

    private struct SchemaProbe: Decodable {
        let schemaVersion: Int
    }

    private let layout: StorageLayout
    private let fileManager = FileManager.default
    private let now: @Sendable () -> Date
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var limits: Limits
    private var clips: [Clip] = []
    private var continuations: [UUID: AsyncStream<[Clip]>.Continuation] = [:]
    private var saveTask: Task<Void, Never>?
    private var hasLoaded = false

    public init(layout: StorageLayout, limits: Limits, now: @escaping @Sendable () -> Date = { Date() }) {
        self.layout = layout
        self.limits = limits
        self.now = now
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - HistoryStoring

    // manifest が正本。index.json は並び順と最終使用時刻のキャッシュで、無くても壊れていても manifest から戻せる。
    // そのため index.json に無いディレクトリを消してはいけない（保存前に終了した取り込みを失う）
    public func load() async {
        do {
            try fileManager.createDirectory(at: layout.clipsDirectory, withIntermediateDirectories: true)
        } catch {
            CoreLog.store.error("保存先を作れない: \(error, privacy: .public)")
        }
        removeTemporaryDirectories()
        let indexed = loadIndex()
        let onDisk = scanClipDirectories()
        var merged: [Clip] = []
        var seen = Set<UUID>()
        for clip in indexed where onDisk[clip.id] != nil {
            merged.append(clip)
            seen.insert(clip.id)
        }
        merged.append(contentsOf: onDisk.values.filter { !seen.contains($0.id) })
        clips = merged.sorted { $0.lastUsedAt > $1.lastUsedAt }
        hasLoaded = true
        prune()
        writeIndexLogged()
    }

    public func snapshot() -> [Clip] {
        clips
    }

    public func updates() -> AsyncStream<[Clip]> {
        let id = UUID()
        // 各要素が完全なスナップショットなので、古いものを捨てても失われる情報は無い
        let (stream, continuation) = AsyncStream<[Clip]>.makeStream(bufferingPolicy: .bufferingNewest(1))
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeContinuation(id) }
        }
        continuation.yield(clips)
        return stream
    }

    @discardableResult
    public func ingest(_ capture: Capture) async -> IngestResult {
        guard !capture.items.isEmpty, capture.byteCount > 0 else { return .rejected(.empty) }
        guard capture.byteCount <= limits.maxClipBytes else { return .rejected(.tooLarge) }
        let hash = ContentHasher.hash(capture)
        if let existing = clips.first(where: { $0.contentHash == hash }), let moved = moveToTop(existing.id) {
            scheduleSave()
            emit()
            return .duplicateMovedToTop(moved)
        }
        let summary = PreviewBuilder.summarize(capture)
        let clip = Clip(
            kind: summary.kind,
            createdAt: capture.capturedAt,
            lastUsedAt: capture.capturedAt,
            sourceBundleID: capture.sourceBundleID,
            preview: summary.preview,
            contentHash: hash,
            hasThumbnail: summary.thumbnail != nil,
            imagePixelSize: summary.thumbnail?.sourcePixelSize,
            fileNames: summary.fileNames
        )
        do {
            try writeClipDirectory(clip: clip, capture: capture, thumbnail: summary.thumbnail?.png)
        } catch {
            CoreLog.store.error("クリップを書き込めない: \(error, privacy: .public)")
            removeItemLogged(layout.temporaryClipDirectory(clip.id))
            return .rejected(.writeFailed(String(describing: error)))
        }
        clips.insert(clip, at: 0)
        prune()
        scheduleSave()
        emit()
        return .inserted(clip)
    }

    public func touch(_ id: Clip.ID) async {
        guard moveToTop(id) != nil else { return }
        scheduleSave()
        emit()
    }

    public func delete(_ id: Clip.ID) async {
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
        clips.remove(at: index)
        removeItemLogged(layout.clipDirectory(id))
        scheduleSave()
        emit()
    }

    public func deleteAll() async {
        for clip in clips {
            removeItemLogged(layout.clipDirectory(clip.id))
        }
        clips = []
        scheduleSave()
        emit()
    }

    public func updateLimits(_ limits: Limits) async {
        self.limits = limits
        prune()
        scheduleSave()
        emit()
    }

    public func loadRepresentations(_ id: Clip.ID) async throws -> [[Representation]] {
        let manifest = try readManifest(id)
        let directory = layout.clipDirectory(id)
        return try manifest.items.map { records in
            try records.map { record in
                let data = try Data(contentsOf: directory.appendingPathComponent(record.file), options: .mappedIfSafe)
                return Representation(type: record.type, data: data)
            }
        }
    }

    public func loadPlainText(_ id: Clip.ID) async throws -> String? {
        let manifest = try readManifest(id)
        let directory = layout.clipDirectory(id)
        let items = try manifest.items.map { records -> CapturedItem in
            let textRecords = records.filter { TextExtractor.textTypes.contains($0.type) }
            let representations = try textRecords.map { record in
                Representation(type: record.type, data: try Data(contentsOf: directory.appendingPathComponent(record.file)))
            }
            return CapturedItem(representations: representations)
        }
        return TextExtractor.text(from: items)
    }

    public func flush() async {
        saveTask?.cancel()
        saveTask = nil
        writeIndexLogged()
    }

    // MARK: - Ordering and limits

    private func moveToTop(_ id: Clip.ID) -> Clip? {
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return nil }
        var clip = clips.remove(at: index)
        clip.lastUsedAt = now()
        clips.insert(clip, at: 0)
        return clip
    }

    private func prune() {
        while clips.count > limits.maxClips {
            let removed = clips.removeLast()
            removeItemLogged(layout.clipDirectory(removed.id))
        }
    }

    // MARK: - Loading

    private func loadIndex() -> [Clip] {
        let data: Data
        do {
            data = try Data(contentsOf: layout.indexURL)
        } catch {
            // 初回起動では無いのが正常。読めない場合も manifest から復元できるので記録だけする
            if fileManager.fileExists(atPath: layout.indexURL.path) {
                CoreLog.store.error("索引を読めない: \(error, privacy: .public)")
            }
            return []
        }
        // 版の判定だけが目的なので、読めなければ下の本復号に任せる
        if let probe = try? decoder.decode(SchemaProbe.self, from: data), probe.schemaVersion > HistoryIndex.currentSchemaVersion {
            backUpIndex(reason: "newer")
            return []
        }
        do {
            return try decoder.decode(HistoryIndex.self, from: data).clips
        } catch {
            CoreLog.store.error("索引が壊れている: \(error, privacy: .public)")
            backUpIndex(reason: "corrupt")
            return []
        }
    }

    private func backUpIndex(reason: String) {
        let destination = layout.indexBackupURL(reason: reason, now: now())
        do {
            try fileManager.moveItem(at: layout.indexURL, to: destination)
        } catch {
            // 退避できなくても manifest から復元して上書きするので先へ進む
            CoreLog.store.error("索引を退避できない: \(error, privacy: .public)")
        }
    }

    private func scanClipDirectories() -> [UUID: Clip] {
        let entries: [URL]
        do {
            entries = try fileManager.contentsOfDirectory(at: layout.clipsDirectory, includingPropertiesForKeys: nil)
        } catch {
            CoreLog.store.error("クリップの一覧を読めない: \(error, privacy: .public)")
            return [:]
        }
        var result: [UUID: Clip] = [:]
        for entry in entries {
            guard let id = UUID(uuidString: entry.lastPathComponent) else { continue }
            // manifest が読めない＝クリップの実体が無いので、理由を問わず削除してよい
            guard let data = try? Data(contentsOf: layout.manifestURL(id)) else {
                CoreLog.store.notice("manifest の無いディレクトリを削除: \(id.uuidString, privacy: .public)")
                removeItemLogged(entry)
                continue
            }
            // 新しい版が作ったクリップは読めなくても消さない（新しい版で開き直せば戻る）。版が読めなければ本復号に任せる
            if let probe = try? decoder.decode(SchemaProbe.self, from: data), probe.schemaVersion > ClipManifest.currentSchemaVersion {
                continue
            }
            let manifest: ClipManifest
            do {
                manifest = try decoder.decode(ClipManifest.self, from: data)
            } catch {
                // 読めない manifest は消さない。型の変更漏れで履歴を失うより、残して直せる方がよい
                CoreLog.store.error("manifest を読めないので飛ばす: \(id.uuidString, privacy: .public) \(error, privacy: .public)")
                continue
            }
            guard filesExist(manifest, in: entry) else {
                CoreLog.store.notice("形式ファイルが欠けたクリップを削除: \(id.uuidString, privacy: .public)")
                removeItemLogged(entry)
                continue
            }
            result[id] = manifest.clip
        }
        return result
    }

    private func filesExist(_ manifest: ClipManifest, in directory: URL) -> Bool {
        for records in manifest.items {
            for record in records where !fileManager.fileExists(atPath: directory.appendingPathComponent(record.file).path) {
                return false
            }
        }
        return true
    }

    private func removeTemporaryDirectories() {
        // 一覧を読めないときは消すものも無いので、エラーは scanClipDirectories 側で記録する
        guard let entries = try? fileManager.contentsOfDirectory(at: layout.clipsDirectory, includingPropertiesForKeys: nil) else { return }
        for entry in entries where entry.lastPathComponent.hasSuffix(".tmp") {
            removeItemLogged(entry)
        }
    }

    // MARK: - Disk

    private func writeClipDirectory(clip: Clip, capture: Capture, thumbnail: Data?) throws {
        let temporary = layout.temporaryClipDirectory(clip.id)
        if fileManager.fileExists(atPath: temporary.path) {
            try fileManager.removeItem(at: temporary)
        }
        try fileManager.createDirectory(at: temporary, withIntermediateDirectories: true)
        var items: [[RepresentationRecord]] = []
        for (itemIndex, item) in capture.items.enumerated() {
            var records: [RepresentationRecord] = []
            for (representationIndex, representation) in item.representations.enumerated() {
                let file = StorageLayout.representationFileName(item: itemIndex, representation: representationIndex)
                try representation.data.write(to: temporary.appendingPathComponent(file))
                records.append(RepresentationRecord(type: representation.type, file: file))
            }
            items.append(records)
        }
        if let thumbnail {
            try thumbnail.write(to: temporary.appendingPathComponent(StorageLayout.thumbnailFileName))
        }
        let manifest = ClipManifest(clip: clip, items: items)
        try encoder.encode(manifest).write(to: temporary.appendingPathComponent(StorageLayout.manifestFileName))
        // ディレクトリごと rename するので、途中で止まっても完成したクリップだけが見える
        try fileManager.moveItem(at: temporary, to: layout.clipDirectory(clip.id))
    }

    private func readManifest(_ id: Clip.ID) throws -> ClipManifest {
        let data = try Data(contentsOf: layout.manifestURL(id))
        return try decoder.decode(ClipManifest.self, from: data)
    }

    private func removeItemLogged(_ url: URL) {
        do {
            try fileManager.removeItem(at: url)
        } catch {
            CoreLog.store.error("削除できない: \(url.lastPathComponent, privacy: .public) \(error, privacy: .public)")
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: FileHistoryStore.indexSaveDelay)
            } catch {
                return
            }
            await self?.writeIndexLogged()
        }
    }

    private func writeIndexLogged() {
        // 読み込み前に書くと、ディスクにある履歴を無視した索引で上書きしてしまう
        guard hasLoaded else { return }
        do {
            try fileManager.createDirectory(at: layout.root, withIntermediateDirectories: true)
            let data = try encoder.encode(HistoryIndex(clips: clips))
            try data.write(to: layout.indexURL, options: .atomic)
        } catch {
            CoreLog.store.error("索引を書けない: \(error, privacy: .public)")
        }
    }

    // MARK: - Updates

    private func emit() {
        for continuation in continuations.values {
            continuation.yield(clips)
        }
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }
}
