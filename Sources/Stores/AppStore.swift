import Foundation
import Observation

struct RecentServerHistory {
    static let maximumCount = 3

    static func sanitized(_ values: [String]) -> [String] {
        values.reduce(into: [String]()) { result, value in
            guard let normalized = try? JellyfinClient.normalizeServer(value).absoluteString,
                !result.contains(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame })
            else {
                return
            }
            result.append(normalized)
        }
        .prefix(maximumCount)
        .map(\.self)
    }

    static func adding(_ value: String, to existing: [String]) -> [String] {
        guard let normalized = try? JellyfinClient.normalizeServer(value).absoluteString else {
            return sanitized(existing)
        }
        return sanitized(
            [normalized]
                + existing.filter {
                    $0.caseInsensitiveCompare(normalized) != .orderedSame
                }
        )
    }
}

@MainActor
@Observable
final class AppStore {
    enum LibraryState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    var session: JellyfinSession?
    var libraries: [MediaLibrary] = []
    private(set) var libraryItems: [String: [MediaItem]] = [:]
    var liveTVChannels: [MediaItem] = []
    var libraryState: LibraryState = .idle
    private(set) var libraryItemStates: [String: LibraryState] = [:]
    var liveTVState: LibraryState = .idle
    var connectionError: String?
    var isConnecting = false
    private(set) var recentServerURLs: [String]

    let downloads: OfflineDownloadStore

    @ObservationIgnored private let keychain = KeychainSessionStore()
    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private var librariesLoadID = UUID()
    @ObservationIgnored private var libraryItemLoadIDs: [String: UUID] = [:]
    @ObservationIgnored private var liveTVLoadID = UUID()

    private static let recentServersKey = "jellyboy.recent-servers"

    init(
        restoreSession: Bool = true,
        downloads: OfflineDownloadStore? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.userDefaults = userDefaults
        self.downloads = downloads ?? OfflineDownloadStore()
        let storedServers = userDefaults.stringArray(forKey: Self.recentServersKey) ?? []
        recentServerURLs = RecentServerHistory.sanitized(storedServers)
        if recentServerURLs != storedServers {
            if recentServerURLs.isEmpty {
                userDefaults.removeObject(forKey: Self.recentServersKey)
            } else {
                userDefaults.set(recentServerURLs, forKey: Self.recentServersKey)
            }
        }
        if ProcessInfo.processInfo.arguments.contains("--demo")
            || ProcessInfo.processInfo.arguments.contains("--demo-player")
        {
            openDemo()
        } else if restoreSession {
            session = try? keychain.load()
            if let session, !session.isDemo {
                rememberServer(session.serverURL)
            }
        }
    }

    var isConnected: Bool { session != nil }
    var isDemo: Bool { session?.isDemo == true }

    func connect(server: String, username: String, password: String) async {
        guard !isConnecting else { return }
        isConnecting = true
        connectionError = nil
        defer { isConnecting = false }

        do {
            let baseURL = try JellyfinClient.normalizeServer(server)
            let client = JellyfinClient(
                baseURL: baseURL,
                deviceID: InstallIdentity.current
            )
            let authenticated = try await client.authenticate(
                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            try keychain.save(authenticated)
            rememberServer(authenticated.serverURL)
            session = authenticated
            libraries = []
            libraryItems = [:]
            libraryState = .idle
            libraryItemStates = [:]
            await loadLibraries()
        } catch is CancellationError {
            return
        } catch {
            connectionError = (error as? LocalizedError)?.errorDescription ?? "CONNECTION FAILED."
        }
    }

    func loadLibraries(force: Bool = false) async {
        guard let session else { return }
        if session.isDemo {
            libraries = MediaLibrary.sampleLibraries
            libraryItems = Dictionary(uniqueKeysWithValues: libraries.map { ($0.id, $0.sampleItems) })
            libraryItemStates = Dictionary(uniqueKeysWithValues: libraries.map { ($0.id, .loaded) })
            libraryState = .loaded
            return
        }
        if !force, libraryState == .loading || libraryState == .loaded { return }
        guard let client = client(for: session) else {
            libraryState = .failed("THE SAVED SERVER IS INVALID.")
            return
        }

        libraryState = .loading
        let loadID = UUID()
        librariesLoadID = loadID
        do {
            let loadedLibraries = try await client.libraries(userID: session.userID)
            guard librariesLoadID == loadID, self.session?.id == session.id else { return }
            let libraryIDs = Set(loadedLibraries.map(\.id))
            libraries = loadedLibraries
            libraryItems = libraryItems.filter { libraryIDs.contains($0.key) }
            libraryItemStates = libraryItemStates.filter { libraryIDs.contains($0.key) }
            libraryState = .loaded
        } catch is CancellationError {
            return
        } catch {
            guard librariesLoadID == loadID, self.session?.id == session.id else { return }
            libraryState = .failed(
                (error as? LocalizedError)?.errorDescription ?? "LIBRARY LOAD FAILED."
            )
        }
    }

    func loadItems(in library: MediaLibrary, force: Bool = false) async {
        guard let session else { return }
        if session.isDemo {
            libraryItems[library.id] = library.sampleItems
            libraryItemStates[library.id] = .loaded
            return
        }
        if !force,
            libraryItems[library.id] != nil || libraryItemStates[library.id] == .loading
        {
            return
        }
        guard let client = client(for: session) else {
            libraryItemStates[library.id] = .failed("THE SAVED SERVER IS INVALID.")
            return
        }

        libraryItemStates[library.id] = .loading
        let loadID = UUID()
        libraryItemLoadIDs[library.id] = loadID
        do {
            let loadedItems = try await client.items(in: library, userID: session.userID)
            guard libraryItemLoadIDs[library.id] == loadID,
                self.session?.id == session.id,
                libraries.contains(where: { $0.id == library.id })
            else {
                return
            }
            libraryItems[library.id] = loadedItems
            libraryItemStates[library.id] = .loaded
        } catch is CancellationError {
            return
        } catch {
            guard libraryItemLoadIDs[library.id] == loadID, self.session?.id == session.id else { return }
            libraryItemStates[library.id] = .failed(
                (error as? LocalizedError)?.errorDescription ?? "LIBRARY ITEMS FAILED TO LOAD."
            )
        }
    }

    func items(in library: MediaLibrary) -> [MediaItem] {
        libraryItems[library.id] ?? []
    }

    func state(for library: MediaLibrary) -> LibraryState {
        libraryItemStates[library.id] ?? .idle
    }

    func episodes(for series: MediaItem) async throws -> [MediaItem] {
        guard let session else { return [] }
        if session.isDemo {
            return MediaItem.sampleEpisodes.filter { $0.seriesID == series.id }
        }
        guard let client = client(for: session) else { throw JellyfinError.invalidServer }
        return try await client.episodes(seriesID: series.id, userID: session.userID)
    }

    func loadLiveTV(force: Bool = false) async {
        guard let session else { return }
        if session.isDemo {
            liveTVChannels = MediaItem.sampleLiveTV
            liveTVState = .loaded
            return
        }
        guard force || liveTVChannels.isEmpty else { return }
        guard let client = client(for: session) else {
            liveTVState = .failed("THE SAVED SERVER IS INVALID.")
            return
        }

        liveTVState = .loading
        let loadID = UUID()
        liveTVLoadID = loadID
        do {
            let loadedChannels = try await client.liveTVChannels(userID: session.userID)
            guard liveTVLoadID == loadID, self.session?.id == session.id else { return }
            liveTVChannels = loadedChannels
            liveTVState = .loaded
        } catch is CancellationError {
            return
        } catch {
            guard liveTVLoadID == loadID, self.session?.id == session.id else { return }
            liveTVState = .failed(
                (error as? LocalizedError)?.errorDescription ?? "LIVE TV LOAD FAILED."
            )
        }
    }

    func imageRequest(for item: MediaItem, maxWidth: Int = 480) -> URLRequest? {
        guard let session, !session.isDemo, let client = client(for: session) else { return nil }
        return client.imageRequest(for: item, maxWidth: maxWidth)
    }

    func playbackPlan(
        for item: MediaItem,
        quality: PlaybackQuality,
        audioStreamIndex: Int? = nil,
        subtitleStreamIndex: Int? = nil,
        allowDirectPlay: Bool = true
    ) async throws -> PlaybackPlan {
        guard let session, !session.isDemo, let client = client(for: session) else {
            throw JellyfinError.invalidServer
        }
        return try await client.playbackPlan(
            for: item,
            userID: session.userID,
            quality: quality,
            audioStreamIndex: audioStreamIndex,
            subtitleStreamIndex: subtitleStreamIndex,
            allowDirectPlay: allowDirectPlay
        )
    }

    func playbackAssetURL(from serverPath: String) -> URL? {
        guard let session, !session.isDemo, let client = client(for: session) else { return nil }
        return client.authenticatedURL(from: serverPath)
    }

    func offlineChoices(for item: MediaItem) async throws -> PlaybackMediaSource {
        guard let session, !session.isDemo, let client = client(for: session) else {
            throw JellyfinError.invalidServer
        }
        return try await client.offlineChoices(for: item, userID: session.userID)
    }

    func offlinePreparation(
        for item: MediaItem,
        options: OfflineDownloadOptions
    ) async throws -> OfflinePreparation {
        guard let session, !session.isDemo, let client = client(for: session) else {
            throw JellyfinError.invalidServer
        }
        return try await client.offlinePreparation(
            for: item,
            userID: session.userID,
            options: options
        )
    }

    func closeLiveStream(_ liveStreamID: String) async {
        guard let session, !session.isDemo, let client = client(for: session) else { return }
        try? await client.closeLiveStream(liveStreamID)
    }

    func openDemo() {
        session = .demo()
        libraries = MediaLibrary.sampleLibraries
        libraryItems = Dictionary(uniqueKeysWithValues: libraries.map { ($0.id, $0.sampleItems) })
        libraryItemStates = Dictionary(uniqueKeysWithValues: libraries.map { ($0.id, .loaded) })
        liveTVChannels = MediaItem.sampleLiveTV
        libraryState = .loaded
        liveTVState = .loaded
        connectionError = nil
    }

    func signOut() {
        librariesLoadID = UUID()
        libraryItemLoadIDs = [:]
        liveTVLoadID = UUID()
        try? keychain.clear()
        session = nil
        libraries = []
        libraryItems = [:]
        liveTVChannels = []
        libraryState = .idle
        libraryItemStates = [:]
        liveTVState = .idle
        connectionError = nil
    }

    func clearRecentServers() {
        recentServerURLs = []
        userDefaults.removeObject(forKey: Self.recentServersKey)
    }

    private func rememberServer(_ value: String) {
        recentServerURLs = RecentServerHistory.adding(value, to: recentServerURLs)
        userDefaults.set(recentServerURLs, forKey: Self.recentServersKey)
    }

    private func client(for session: JellyfinSession) -> JellyfinClient? {
        guard let baseURL = session.baseURL else { return nil }
        return JellyfinClient(
            baseURL: baseURL,
            accessToken: session.accessToken,
            deviceID: session.deviceID
        )
    }

    static func previewLibrary() -> AppStore {
        let store = AppStore(restoreSession: false)
        store.openDemo()
        return store
    }

    static func previewSignedOut() -> AppStore {
        AppStore(restoreSession: false)
    }
}
