import Foundation

struct OfflineDownloadOptions: Equatable, Sendable {
    let quality: PlaybackQuality
    let audioStreamIndex: Int?
    let subtitleStreamIndex: Int?
}

struct OfflinePreparation: Sendable {
    let downloadURL: URL
    let subtitleURL: URL?
    let source: PlaybackMediaSource
    let engine: PlaybackEngine
    let mediaFileExtension: String
    let selectedAudioIndex: Int?
    let selectedSubtitleIndex: Int?
    let quality: PlaybackQuality
}

struct OfflineDownload: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let item: MediaItem
    let quality: PlaybackQuality
    let source: PlaybackMediaSource
    let engine: PlaybackEngine
    let selectedAudioIndex: Int?
    let selectedSubtitleIndex: Int?
    let mediaFilename: String
    let subtitleFilename: String?
    let posterFilename: String?
    let byteCount: Int64
    let createdAt: Date

    func directoryURL(in rootURL: URL) -> URL {
        rootURL.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    func mediaURL(in rootURL: URL) -> URL {
        directoryURL(in: rootURL).appendingPathComponent(mediaFilename)
    }

    func subtitleURL(in rootURL: URL) -> URL? {
        subtitleFilename.map { directoryURL(in: rootURL).appendingPathComponent($0) }
    }

    func posterURL(in rootURL: URL) -> URL? {
        posterFilename.map { directoryURL(in: rootURL).appendingPathComponent($0) }
    }

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file).uppercased()
    }

    var audioTitle: String {
        source.audioStreams.first { $0.index == selectedAudioIndex }?.selectorTitle ?? "AUTO"
    }

    var subtitleTitle: String {
        source.subtitleStreams.first { $0.index == selectedSubtitleIndex }?.selectorTitle ?? "OFF"
    }
}

enum OfflineDownloadPhase: Equatable, Sendable {
    case preparing
    case downloading
    case failed(String)

    var title: String {
        switch self {
        case .preparing: "PREPARING..."
        case .downloading: "DOWNLOADING..."
        case .failed: "TRY DOWNLOAD AGAIN"
        }
    }

    var accessibilityTitle: String {
        switch self {
        case .preparing: "PREPARING DOWNLOAD"
        case .downloading: "DOWNLOADING"
        case .failed: "DOWNLOAD FAILED"
        }
    }
}

enum OfflineDownloadError: LocalizedError {
    case liveContent
    case noSource
    case noProgressiveStream
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .liveContent: "LIVE TV CAN'T BE DOWNLOADED."
        case .noSource: "THIS TITLE HAS NO DOWNLOADABLE MEDIA SOURCE."
        case .noProgressiveStream: "THE SERVER COULDN'T PREPARE THIS OFFLINE VERSION."
        case .invalidResponse: "THE DOWNLOAD SERVER RETURNED AN INVALID FILE."
        }
    }
}
