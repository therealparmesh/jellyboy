import Foundation
import Observation

@MainActor
@Observable
final class OfflineDownloadStore {
    private(set) var records: [OfflineDownload] = []
    private(set) var phases: [String: OfflineDownloadPhase] = [:]
    private(set) var activeItems: [String: MediaItem] = [:]

    @ObservationIgnored private var tasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var stagingDirectories: [String: URL] = [:]
    @ObservationIgnored let rootURL: URL

    init(rootURL: URL? = nil) {
        self.rootURL = rootURL ?? Self.defaultRootURL
        prepareRoot()
        loadManifest()
    }

    var totalByteCount: Int64 {
        records.reduce(0) { $0 + $1.byteCount }
    }

    var listedItems: [MediaItem] {
        let active = activeItems.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        let activeIDs = Set(activeItems.keys)
        return active + records.lazy.filter { !activeIDs.contains($0.item.id) }.map(\.item)
    }

    var totalSizeText: String {
        ByteCountFormatter.string(fromByteCount: totalByteCount, countStyle: .file).uppercased()
    }

    func record(for itemID: String) -> OfflineDownload? {
        records.first { $0.item.id == itemID }
    }

    func phase(for itemID: String) -> OfflineDownloadPhase? {
        phases[itemID]
    }

    func mediaURL(for record: OfflineDownload) -> URL {
        record.mediaURL(in: rootURL)
    }

    func subtitleURL(for record: OfflineDownload) -> URL? {
        record.subtitleURL(in: rootURL)
    }

    func posterURL(for record: OfflineDownload) -> URL? {
        record.posterURL(in: rootURL)
    }

    func start(
        item: MediaItem,
        options: OfflineDownloadOptions,
        store: AppStore
    ) {
        guard tasks[item.id] == nil else { return }
        phases[item.id] = .preparing
        activeItems[item.id] = item

        tasks[item.id] = Task { @MainActor [weak self, weak store] in
            guard let self, let store else { return }
            await self.performDownload(item: item, options: options, store: store)
            self.tasks[item.id] = nil
        }
    }

    func remove(_ record: OfflineDownload) {
        cancel(itemID: record.item.id)
        removeDirectory(record.directoryURL(in: rootURL))
        records.removeAll { $0.id == record.id }
        saveManifest()
    }

    func cancel(itemID: String) {
        tasks[itemID]?.cancel()
        tasks[itemID] = nil
        clearActiveDownload(itemID: itemID, removeStaging: true)
    }

    func clearAll() {
        for task in tasks.values {
            task.cancel()
        }
        tasks.removeAll()
        phases.removeAll()
        activeItems.removeAll()
        for directory in stagingDirectories.values {
            removeDirectory(directory)
        }
        stagingDirectories.removeAll()
        for record in records {
            removeDirectory(record.directoryURL(in: rootURL))
        }
        records.removeAll()
        saveManifest()
    }

    private func performDownload(
        item: MediaItem,
        options: OfflineDownloadOptions,
        store: AppStore
    ) async {
        let recordID = UUID()
        let directoryURL = rootURL.appendingPathComponent(recordID.uuidString, isDirectory: true)
        stagingDirectories[item.id] = directoryURL

        do {
            let preparation = try await store.offlinePreparation(for: item, options: options)
            try Task.checkCancellation()
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            phases[item.id] = .downloading

            let mediaExtension = Self.safeFileExtension(preparation.mediaFileExtension)
            let mediaFilename = "media.\(mediaExtension)"
            let mediaURL = directoryURL.appendingPathComponent(mediaFilename)
            let mediaBytes = try await download(preparation.downloadURL, to: mediaURL)
            try Task.checkCancellation()

            let subtitleFilename: String?
            let subtitleBytes: Int64
            if let subtitleURL = preparation.subtitleURL {
                subtitleFilename = "subtitle.vtt"
                subtitleBytes = try await download(
                    subtitleURL,
                    to: directoryURL.appendingPathComponent("subtitle.vtt")
                )
            } else {
                subtitleFilename = nil
                subtitleBytes = 0
            }

            let posterFilename: String?
            let posterBytes: Int64
            if let request = store.imageRequest(for: item, maxWidth: 900) {
                do {
                    posterBytes = try await download(
                        request,
                        to: directoryURL.appendingPathComponent("poster.img")
                    )
                    posterFilename = "poster.img"
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    posterFilename = nil
                    posterBytes = 0
                }
            } else {
                posterFilename = nil
                posterBytes = 0
            }

            try Task.checkCancellation()
            let newRecord = OfflineDownload(
                id: recordID,
                item: item,
                quality: preparation.quality,
                source: preparation.source.sanitizedForOfflineStorage,
                engine: preparation.engine,
                selectedAudioIndex: preparation.selectedAudioIndex,
                selectedSubtitleIndex: preparation.selectedSubtitleIndex,
                mediaFilename: mediaFilename,
                subtitleFilename: subtitleFilename,
                posterFilename: posterFilename,
                byteCount: mediaBytes + subtitleBytes + posterBytes,
                createdAt: Date()
            )

            if let previous = record(for: item.id) {
                removeDirectory(previous.directoryURL(in: rootURL))
                records.removeAll { $0.id == previous.id }
            }
            records.insert(newRecord, at: 0)
            saveManifest()
            clearActiveDownload(itemID: item.id, removeStaging: false)
        } catch is CancellationError {
            clearActiveDownload(itemID: item.id, removeStaging: true)
        } catch {
            if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                clearActiveDownload(itemID: item.id, removeStaging: true)
            } else {
                removeDirectory(directoryURL)
                stagingDirectories[item.id] = nil
                phases[item.id] = .failed(
                    (error as? LocalizedError)?.errorDescription ?? "THE DOWNLOAD FAILED."
                )
            }
        }
    }

    private func clearActiveDownload(itemID: String, removeStaging: Bool) {
        phases[itemID] = nil
        activeItems[itemID] = nil
        if let stagingURL = stagingDirectories.removeValue(forKey: itemID), removeStaging {
            removeDirectory(stagingURL)
        }
    }

    private func download(_ url: URL, to destination: URL) async throws -> Int64 {
        let (temporaryURL, response) = try await URLSession.shared.download(from: url)
        return try moveDownloadedFile(temporaryURL, response: response, to: destination)
    }

    private func download(_ request: URLRequest, to destination: URL) async throws -> Int64 {
        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        return try moveDownloadedFile(temporaryURL, response: response, to: destination)
    }

    private func moveDownloadedFile(
        _ temporaryURL: URL,
        response: URLResponse,
        to destination: URL
    ) throws -> Int64 {
        guard let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode)
        else {
            throw OfflineDownloadError.invalidResponse
        }
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        let values = try destination.resourceValues(forKeys: [.fileSizeKey])
        let byteCount = Int64(values.fileSize ?? 0)
        guard byteCount > 0 else {
            try? FileManager.default.removeItem(at: destination)
            throw OfflineDownloadError.invalidResponse
        }
        return byteCount
    }

    private func prepareRoot() {
        try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableRoot = rootURL
        try? mutableRoot.setResourceValues(values)
    }

    private func loadManifest() {
        guard let data = try? Data(contentsOf: manifestURL),
            let decoded = try? JSONDecoder().decode([OfflineDownload].self, from: data)
        else {
            return
        }
        let validRecords = decoded.filter {
            FileManager.default.fileExists(atPath: $0.mediaURL(in: rootURL).path)
        }
        records = validRecords

        let validIDs = Set(validRecords.map { $0.id.uuidString })
        if let contents = try? FileManager.default.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for url in contents where url.lastPathComponent != manifestURL.lastPathComponent {
                guard UUID(uuidString: url.lastPathComponent) != nil,
                    !validIDs.contains(url.lastPathComponent)
                else { continue }
                removeDirectory(url)
            }
        }

        if validRecords.count != decoded.count {
            saveManifest()
        }
    }

    private func saveManifest() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: manifestURL, options: .atomic)
    }

    private func removeDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private var manifestURL: URL {
        rootURL.appendingPathComponent("manifest.json")
    }

    private static var defaultRootURL: URL {
        let applicationSupportURL = URL.applicationSupportDirectory
        let containerURL = applicationSupportURL.appendingPathComponent("jellyboy", isDirectory: true)
        normalizeContainerName(in: applicationSupportURL, to: containerURL)
        return
            containerURL
            .appendingPathComponent("Downloads", isDirectory: true)
    }

    static func normalizeContainerName(in parentURL: URL, to containerURL: URL) {
        let fileManager = FileManager.default
        guard
            let contents = try? fileManager.contentsOfDirectory(
                at: parentURL,
                includingPropertiesForKeys: nil
            ),
            !contents.contains(where: { $0.lastPathComponent == containerURL.lastPathComponent }),
            let differentlyCasedURL = contents.first(where: {
                $0.lastPathComponent.lowercased() == containerURL.lastPathComponent
            })
        else { return }

        let temporaryURL = parentURL.appendingPathComponent(
            ".jellyboy-case-migration-\(UUID().uuidString)",
            isDirectory: true
        )
        do {
            try fileManager.moveItem(at: differentlyCasedURL, to: temporaryURL)
            try fileManager.moveItem(at: temporaryURL, to: containerURL)
        } catch {
            if fileManager.fileExists(atPath: temporaryURL.path) {
                try? fileManager.moveItem(at: temporaryURL, to: differentlyCasedURL)
            }
        }
    }

    private static func safeFileExtension(_ value: String) -> String {
        let first =
            value
            .lowercased()
            .split(separator: ",")
            .first
            .map(String.init) ?? "media"
        let sanitized = first.filter { $0.isLetter || $0.isNumber }
        return sanitized.isEmpty ? "media" : sanitized
    }
}
