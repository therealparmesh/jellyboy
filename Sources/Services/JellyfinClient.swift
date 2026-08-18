import Foundation

struct JellyfinClient {
    static let name = "jellyboy"
    static let version = "1.0.0"

    let baseURL: URL
    let accessToken: String?
    let deviceID: String

    private let urlSession: URLSession

    init(
        baseURL: URL,
        accessToken: String? = nil,
        deviceID: String,
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.accessToken = accessToken
        self.deviceID = deviceID
        self.urlSession = urlSession
    }

    static func normalizeServer(_ rawValue: String) throws -> URL {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw JellyfinError.invalidServer }

        if !value.contains("://") {
            value = "http://" + value
        }

        guard var components = URLComponents(string: value),
            let scheme = components.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            components.host != nil
        else {
            throw JellyfinError.invalidServer
        }

        components.scheme = scheme
        components.user = nil
        components.password = nil
        components.query = nil
        components.fragment = nil
        if components.path == "/" {
            components.path = ""
        } else {
            while components.path.hasSuffix("/") {
                components.path.removeLast()
            }
        }

        guard let url = components.url else { throw JellyfinError.invalidServer }
        return url
    }

    func authenticate(username: String, password: String) async throws -> JellyfinSession {
        let body = AuthenticationBody(username: username, password: password)
        var request = try makeRequest(path: "Users/AuthenticateByName", method: "POST")
        request.httpBody = try JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let result: AuthenticationResult = try await perform(request)
        guard let user = result.user,
            let token = result.accessToken,
            !token.isEmpty
        else {
            throw JellyfinError.invalidResponse
        }

        return JellyfinSession(
            serverURL: baseURL.absoluteString,
            userID: user.id,
            username: user.name,
            accessToken: token,
            deviceID: deviceID,
            isDemo: false
        )
    }

    func libraries(userID: String) async throws -> [MediaLibrary] {
        let request = try makeRequest(
            path: "Users/\(userID)/Views",
            queryItems: [
                URLQueryItem(name: "includeExternalContent", value: "false")
            ]
        )
        let result: MediaLibraryQueryResult = try await perform(request)
        return result.items
    }

    func items(in library: MediaLibrary, userID: String) async throws -> [MediaItem] {
        let request = try makeRequest(
            path: "Items",
            queryItems: [
                URLQueryItem(name: "userId", value: userID),
                URLQueryItem(name: "parentId", value: library.id),
                URLQueryItem(name: "recursive", value: "true"),
                URLQueryItem(name: "includeItemTypes", value: library.includedItemTypes),
                URLQueryItem(name: "fields", value: "Overview,PrimaryImageAspectRatio,MediaSources"),
                URLQueryItem(name: "sortBy", value: "SortName"),
                URLQueryItem(name: "sortOrder", value: "Ascending"),
                URLQueryItem(name: "enableUserData", value: "true"),
                URLQueryItem(name: "enableImages", value: "true"),
                URLQueryItem(name: "enableImageTypes", value: "Primary"),
                URLQueryItem(name: "imageTypeLimit", value: "1"),
            ]
        )
        let result: ItemQueryResult = try await perform(request)
        return result.items
    }

    func episodes(seriesID: String, userID: String) async throws -> [MediaItem] {
        let request = try makeRequest(
            path: "Shows/\(seriesID)/Episodes",
            queryItems: [
                URLQueryItem(name: "userId", value: userID),
                URLQueryItem(name: "fields", value: "Overview,MediaSources"),
                URLQueryItem(name: "enableUserData", value: "true"),
                URLQueryItem(name: "enableImages", value: "true"),
                URLQueryItem(name: "enableImageTypes", value: "Primary"),
                URLQueryItem(name: "imageTypeLimit", value: "1"),
            ]
        )
        let result: ItemQueryResult = try await perform(request)
        return result.items
    }

    func liveTVChannels(userID: String) async throws -> [MediaItem] {
        let request = try makeRequest(
            path: "LiveTv/Channels",
            queryItems: [
                URLQueryItem(name: "userId", value: userID),
                URLQueryItem(name: "addCurrentProgram", value: "true"),
                URLQueryItem(name: "enableFavoriteSorting", value: "true"),
                URLQueryItem(name: "fields", value: "Overview,MediaSources"),
                URLQueryItem(name: "enableUserData", value: "true"),
                URLQueryItem(name: "enableImages", value: "true"),
                URLQueryItem(name: "enableImageTypes", value: "Primary"),
                URLQueryItem(name: "imageTypeLimit", value: "1"),
            ]
        )
        let result: ItemQueryResult = try await perform(request)
        return result.items
    }

    func imageRequest(for item: MediaItem, maxWidth: Int = 480) -> URLRequest? {
        guard let tag = item.imageTag else { return nil }
        return try? makeRequest(
            path: "Items/\(item.id)/Images/Primary",
            queryItems: [
                URLQueryItem(name: "maxWidth", value: String(maxWidth)),
                URLQueryItem(name: "quality", value: "82"),
                URLQueryItem(name: "tag", value: tag),
            ]
        )
    }

    func playbackPlan(
        for item: MediaItem,
        userID: String,
        quality: PlaybackQuality,
        audioStreamIndex: Int? = nil,
        subtitleStreamIndex: Int? = nil,
        allowDirectPlay: Bool = true
    ) async throws -> PlaybackPlan {
        guard let accessToken, !accessToken.isEmpty else {
            throw JellyfinError.invalidResponse
        }

        let negotiationBitrate = quality.maximumBitrate
        let body = PlaybackInfoRequest(
            userID: userID,
            startTimeTicks: item.resumeTicks > 0 ? item.resumeTicks : nil,
            audioStreamIndex: audioStreamIndex,
            subtitleStreamIndex: subtitleStreamIndex,
            maxStreamingBitrate: negotiationBitrate,
            deviceProfile: .jellyboy(maximumBitrate: negotiationBitrate),
            enableDirectPlay: allowDirectPlay
        )
        let response = try await playbackInfo(for: item, request: body)
        let sources = eligibleSources(
            in: response,
            for: item,
            audioStreamIndex: audioStreamIndex,
            subtitleStreamIndex: subtitleStreamIndex
        )
        guard !sources.isEmpty else {
            throw JellyfinError.noPlayableStream
        }

        if allowDirectPlay {
            for source in sources where !exceedsBitrateLimit(source, maximumBitrate: quality.maximumBitrate) {
                if item.isLiveChannel, source.supportsDirectPlay,
                    let url = liveDirectPlaybackURL(from: source, token: accessToken)
                {
                    return PlaybackPlan(
                        url: url,
                        source: source,
                        engine: .vlc,
                        method: .directPlay,
                        quality: quality
                    )
                }

                if !item.isLiveChannel, source.supportsDirectPlay,
                    let directURL = directPlaybackURL(
                        itemID: item.id,
                        isAudio: item.isAudio,
                        sourceID: source.id ?? item.id,
                        playSessionID: response.playSessionID,
                        token: accessToken
                    )
                {
                    return PlaybackPlan(
                        url: directURL,
                        source: source,
                        engine: source.isNativeApplePlayback ? .native : .vlc,
                        method: .directPlay,
                        quality: quality
                    )
                }
            }
        }

        for source in sources where !exceedsBitrateLimit(source, maximumBitrate: quality.maximumBitrate) {
            if source.supportsDirectStream,
                let transcodingURL = source.transcodingURL,
                let url = authenticatedServerURL(from: transcodingURL, token: accessToken)
            {
                return PlaybackPlan(
                    url: url,
                    source: source,
                    engine: .native,
                    method: .directStream,
                    quality: quality
                )
            }
        }

        for source in sources {
            if source.supportsTranscoding,
                let transcodingURL = source.transcodingURL,
                let url = authenticatedServerURL(from: transcodingURL, token: accessToken)
            {
                return PlaybackPlan(
                    url: url,
                    source: source,
                    engine: .native,
                    method: .transcode,
                    quality: quality
                )
            }
        }

        throw JellyfinError.noPlayableStream
    }

    func offlineChoices(for item: MediaItem, userID: String) async throws -> PlaybackMediaSource {
        guard !item.isLiveChannel else { throw OfflineDownloadError.liveContent }
        let response = try await offlinePlaybackInfo(
            for: item,
            userID: userID,
            quality: .maximum,
            audioStreamIndex: nil,
            subtitleStreamIndex: nil
        )
        guard
            let source = offlineSource(
                in: response,
                for: item,
                quality: .maximum,
                audioStreamIndex: nil,
                subtitleStreamIndex: nil
            )
        else {
            throw OfflineDownloadError.noSource
        }
        return source
    }

    func offlinePreparation(
        for item: MediaItem,
        userID: String,
        options: OfflineDownloadOptions
    ) async throws -> OfflinePreparation {
        guard !item.isLiveChannel else { throw OfflineDownloadError.liveContent }
        guard let accessToken, !accessToken.isEmpty else { throw JellyfinError.invalidResponse }

        let response = try await offlinePlaybackInfo(
            for: item,
            userID: userID,
            quality: options.quality,
            audioStreamIndex: options.audioStreamIndex,
            subtitleStreamIndex: options.subtitleStreamIndex
        )
        guard
            let source = offlineSource(
                in: response,
                for: item,
                quality: options.quality,
                audioStreamIndex: options.audioStreamIndex,
                subtitleStreamIndex: options.subtitleStreamIndex
            )
        else {
            throw OfflineDownloadError.noSource
        }

        let selectedSubtitle = source.subtitleStreams.first { $0.index == options.subtitleStreamIndex }
        let requiresBurnIn = selectedSubtitle?.requiresBurnInForOffline == true
        let mustTranscode =
            exceedsBitrateLimit(source, maximumBitrate: options.quality.maximumBitrate)
            || requiresBurnIn
        let downloadURL: URL
        let method: PlaybackMethod
        let mediaFileExtension: String

        if mustTranscode {
            guard source.supportsTranscoding,
                let value = source.transcodingURL,
                let url = authenticatedServerURL(from: value, token: accessToken)
            else {
                throw OfflineDownloadError.noProgressiveStream
            }
            downloadURL = url
            method = .transcode
            mediaFileExtension = item.isAudio ? "mp3" : "mp4"
        } else if source.supportsDirectPlay,
            let url = directPlaybackURL(
                itemID: item.id,
                isAudio: item.isAudio,
                sourceID: source.id ?? item.id,
                playSessionID: response.playSessionID,
                token: accessToken
            )
        {
            downloadURL = url
            method = .directPlay
            mediaFileExtension = source.primaryContainer ?? (item.isAudio ? "audio" : "video")
        } else if source.supportsDirectStream,
            let value = source.transcodingURL,
            let url = authenticatedServerURL(from: value, token: accessToken)
        {
            downloadURL = url
            method = .directStream
            mediaFileExtension = item.isAudio ? "mp3" : "mp4"
        } else if source.supportsTranscoding,
            let value = source.transcodingURL,
            let url = authenticatedServerURL(from: value, token: accessToken)
        {
            downloadURL = url
            method = .transcode
            mediaFileExtension = item.isAudio ? "mp3" : "mp4"
        } else {
            throw OfflineDownloadError.noProgressiveStream
        }

        let subtitleURL: URL?
        if let selectedSubtitle, !requiresBurnIn {
            guard let sourceID = source.id,
                let url = authenticatedSubtitleURL(
                    itemID: item.id,
                    mediaSourceID: sourceID,
                    streamIndex: selectedSubtitle.index,
                    token: accessToken
                )
            else {
                throw OfflineDownloadError.noProgressiveStream
            }
            subtitleURL = url
        } else {
            subtitleURL = nil
        }

        let engine: PlaybackEngine
        if subtitleURL != nil {
            engine = .vlc
        } else if method == .transcode || method == .directStream {
            engine = .native
        } else {
            engine = source.isNativeApplePlayback ? .native : .vlc
        }

        return OfflinePreparation(
            downloadURL: downloadURL,
            subtitleURL: subtitleURL,
            source: source,
            engine: engine,
            mediaFileExtension: mediaFileExtension,
            selectedAudioIndex: options.audioStreamIndex,
            selectedSubtitleIndex: options.subtitleStreamIndex,
            quality: options.quality
        )
    }

    func closeLiveStream(_ liveStreamID: String) async throws {
        let request = try makeRequest(
            path: "LiveStreams/Close",
            queryItems: [URLQueryItem(name: "liveStreamId", value: liveStreamID)],
            method: "POST"
        )
        try await performEmpty(request)
    }

    func endpointURL(path: String, queryItems: [URLQueryItem] = []) -> URL? {
        var url = baseURL
        for component in path.split(separator: "/") {
            url.appendPathComponent(String(component))
        }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let filteredItems = queryItems.filter { $0.value != nil }
        components.queryItems = filteredItems.isEmpty ? nil : filteredItems
        return components.url
    }

    func authenticatedURL(from serverPath: String) -> URL? {
        guard let accessToken, !accessToken.isEmpty else { return nil }
        return authenticatedServerURL(from: serverPath, token: accessToken)
    }
    private func orderedSources(
        in response: PlaybackInfoResponse,
        for item: MediaItem
    ) -> [PlaybackMediaSource] {
        let preferredIDs = item.mediaSources?.compactMap(\.id) ?? []
        guard !preferredIDs.isEmpty else { return response.mediaSources }

        let preferred = preferredIDs.compactMap { preferredID in
            response.mediaSources.first { $0.id == preferredID }
        }
        let preferredSet = Set(preferred.compactMap(\.id))
        return preferred
            + response.mediaSources.filter { source in
                guard let id = source.id else { return true }
                return !preferredSet.contains(id)
            }
    }

    private func exceedsBitrateLimit(
        _ source: PlaybackMediaSource,
        maximumBitrate: Int
    ) -> Bool {
        source.bitrate.map { $0 > maximumBitrate }
            ?? (maximumBitrate < PlaybackQuality.maximum.rawValue)
    }

    private func directPlaybackURL(
        itemID: String,
        isAudio: Bool,
        sourceID: String,
        playSessionID: String?,
        token: String
    ) -> URL? {
        endpointURL(
            path: Self.directPlaybackPath(itemID: itemID, isAudio: isAudio),
            queryItems: [
                URLQueryItem(name: "Static", value: "true"),
                URLQueryItem(name: "MediaSourceId", value: sourceID),
                URLQueryItem(name: "DeviceId", value: deviceID),
                URLQueryItem(name: "PlaySessionId", value: playSessionID),
                URLQueryItem(name: "api_key", value: token),
            ]
        )
    }

    static func directPlaybackPath(itemID: String, isAudio: Bool) -> String {
        "\(isAudio ? "Audio" : "Videos")/\(itemID)/stream"
    }

    static func subtitleStreamPath(
        itemID: String,
        mediaSourceID: String,
        streamIndex: Int
    ) -> String {
        "Videos/\(itemID)/\(mediaSourceID)/Subtitles/\(streamIndex)/Stream.vtt"
    }

    private func offlinePlaybackInfo(
        for item: MediaItem,
        userID: String,
        quality: PlaybackQuality,
        audioStreamIndex: Int?,
        subtitleStreamIndex: Int?
    ) async throws -> PlaybackInfoResponse {
        let negotiationBitrate = quality.maximumBitrate
        let body = PlaybackInfoRequest(
            userID: userID,
            startTimeTicks: nil,
            audioStreamIndex: audioStreamIndex,
            subtitleStreamIndex: subtitleStreamIndex,
            maxStreamingBitrate: negotiationBitrate,
            deviceProfile: .offlineDownload(maximumBitrate: negotiationBitrate),
            enableDirectPlay: true
        )
        return try await playbackInfo(for: item, request: body)
    }

    private func playbackInfo(
        for item: MediaItem,
        request body: PlaybackInfoRequest
    ) async throws -> PlaybackInfoResponse {
        var request = try makeRequest(path: "Items/\(item.id)/PlaybackInfo", method: "POST")
        request.httpBody = try JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await perform(request)
    }

    private func authenticatedSubtitleURL(
        itemID: String,
        mediaSourceID: String,
        streamIndex: Int,
        token: String
    ) -> URL? {
        endpointURL(
            path: Self.subtitleStreamPath(
                itemID: itemID,
                mediaSourceID: mediaSourceID,
                streamIndex: streamIndex
            ),
            queryItems: [URLQueryItem(name: "api_key", value: token)]
        )
    }

    private func authenticatedServerURL(from value: String, token: String) -> URL? {
        guard let supplied = URLComponents(string: value) else { return nil }

        var result: URLComponents
        if supplied.scheme != nil, let absoluteURL = supplied.url {
            guard let scheme = supplied.scheme?.lowercased(),
                scheme == "http" || scheme == "https",
                supplied.host != nil
            else {
                return nil
            }
            guard isSameOrigin(supplied) else { return absoluteURL }
            guard let absolute = URLComponents(url: absoluteURL, resolvingAgainstBaseURL: false) else {
                return nil
            }
            result = absolute
        } else {
            let path = supplied.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard let serverURL = endpointURL(path: path, queryItems: supplied.queryItems ?? []),
                let serverComponents = URLComponents(url: serverURL, resolvingAgainstBaseURL: false)
            else {
                return nil
            }
            result = serverComponents
        }

        var queryItems = result.queryItems ?? []
        if !queryItems.contains(where: { $0.name.caseInsensitiveCompare("api_key") == .orderedSame }) {
            queryItems.append(URLQueryItem(name: "api_key", value: token))
        }
        result.queryItems = queryItems
        return result.url
    }

    private func isSameOrigin(_ components: URLComponents) -> Bool {
        guard components.scheme?.caseInsensitiveCompare(baseURL.scheme ?? "") == .orderedSame,
            components.host?.caseInsensitiveCompare(baseURL.host ?? "") == .orderedSame
        else {
            return false
        }

        func effectivePort(for value: URLComponents) -> Int? {
            if let port = value.port { return port }
            switch value.scheme?.lowercased() {
            case "http": return 80
            case "https": return 443
            default: return nil
            }
        }

        guard let baseComponents = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return false
        }
        return effectivePort(for: components) == effectivePort(for: baseComponents)
    }

    private func liveDirectPlaybackURL(from source: PlaybackMediaSource, token: String) -> URL? {
        guard let path = source.path, let supplied = URL(string: path) else { return nil }
        guard let scheme = supplied.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return nil
        }

        if let components = URLComponents(url: supplied, resolvingAgainstBaseURL: false),
            isSameOrigin(components)
        {
            return authenticatedServerURL(from: path, token: token)
        }
        return supplied
    }

    private func makeRequest(
        path: String,
        queryItems: [URLQueryItem] = [],
        method: String = "GET"
    ) throws -> URLRequest {
        guard let url = endpointURL(path: path, queryItems: queryItems) else {
            throw JellyfinError.invalidServer
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
        return request
    }

    private var authorizationHeader: String {
        var fields = [
            "Client=\"\(Self.name)\"",
            "Device=\"Apple\"",
            "DeviceId=\"\(deviceID.headerSafe)\"",
            "Version=\"\(Self.version)\"",
        ]
        if let accessToken, !accessToken.isEmpty {
            fields.append("Token=\"\(accessToken.headerSafe)\"")
        }
        return "MediaBrowser " + fields.joined(separator: ", ")
    }

    private func perform<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let data = try await responseData(for: request)
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw JellyfinError.decoding
        }
    }

    private func offlineSource(
        in response: PlaybackInfoResponse,
        for item: MediaItem,
        quality: PlaybackQuality,
        audioStreamIndex: Int?,
        subtitleStreamIndex: Int?
    ) -> PlaybackMediaSource? {
        let sources = eligibleSources(
            in: response,
            for: item,
            audioStreamIndex: audioStreamIndex,
            subtitleStreamIndex: subtitleStreamIndex
        )

        for rank in 0...2 {
            if let source = sources.first(where: {
                offlineRank(
                    $0,
                    quality: quality,
                    subtitleStreamIndex: subtitleStreamIndex
                ) == rank
            }) {
                return source
            }
        }
        return nil
    }

    private func eligibleSources(
        in response: PlaybackInfoResponse,
        for item: MediaItem,
        audioStreamIndex: Int?,
        subtitleStreamIndex: Int?
    ) -> [PlaybackMediaSource] {
        orderedSources(in: response, for: item).filter { source in
            let hasSelectedAudio =
                audioStreamIndex.map { selectedIndex in
                    source.audioStreams.contains { $0.index == selectedIndex }
                } ?? true
            let hasSelectedSubtitle =
                subtitleStreamIndex.map { selectedIndex in
                    source.subtitleStreams.contains { $0.index == selectedIndex }
                } ?? true
            return hasSelectedAudio && hasSelectedSubtitle
        }
    }

    private func offlineRank(
        _ source: PlaybackMediaSource,
        quality: PlaybackQuality,
        subtitleStreamIndex: Int?
    ) -> Int {
        let selectedSubtitle = source.subtitleStreams.first { $0.index == subtitleStreamIndex }
        let requiresTranscode =
            selectedSubtitle?.requiresBurnInForOffline == true
            || exceedsBitrateLimit(source, maximumBitrate: quality.maximumBitrate)

        if requiresTranscode {
            return source.supportsTranscoding && source.transcodingURL != nil ? 2 : Int.max
        }
        if source.supportsDirectPlay { return 0 }
        if source.supportsDirectStream && source.transcodingURL != nil { return 1 }
        if source.supportsTranscoding && source.transcodingURL != nil { return 2 }
        return Int.max
    }

    private func performEmpty(_ request: URLRequest) async throws {
        _ = try await responseData(for: request)
    }

    private func responseData(for request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw JellyfinError.invalidResponse
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw JellyfinError.http(
                    status: httpResponse.statusCode,
                    message: Self.serverMessage(from: data)
                )
            }
            return data
        } catch let error as JellyfinError {
            throw error
        } catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            throw JellyfinError.network(error.localizedDescription)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw JellyfinError.network(error.localizedDescription)
        }
    }

    private static func serverMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return (object["Message"] as? String) ?? (object["message"] as? String)
    }
}

private struct AuthenticationBody: Encodable {
    let username: String
    let password: String

    enum CodingKeys: String, CodingKey {
        case username = "Username"
        case password = "Pw"
    }
}

enum JellyfinError: LocalizedError {
    case invalidServer
    case invalidResponse
    case noPlayableStream
    case decoding
    case http(status: Int, message: String?)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidServer:
            return "CHECK THE SERVER ADDRESS."
        case .invalidResponse, .decoding:
            return "THE SERVER SENT AN UNKNOWN RESPONSE."
        case .noPlayableStream:
            return "THIS TITLE HAS NO PLAYABLE STREAM."
        case .http(let status, let message):
            if status == 401 { return "CHECK THE USERNAME OR PASSWORD." }
            if status == 403 { return "THIS ACCOUNT CAN'T OPEN THAT." }
            return message?.uppercased() ?? "SERVER ERROR \(status)."
        case .network:
            return "CAN'T REACH THE SERVER."
        }
    }
}

extension String {
    fileprivate var headerSafe: String {
        replacingOccurrences(of: "\\", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }
}
