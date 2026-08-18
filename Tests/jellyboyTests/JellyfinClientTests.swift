import XCTest

@testable import jellyboy

final class JellyfinClientTests: XCTestCase {
    func testGameCompatibilityPalettesPreserveSameBoyRGB555Values() {
        XCTAssertEqual(
            GBCCompatibilityPalette.blue,
            GBCCompatibilityPalette(
                lightest: 0x7FFF,
                light: 0x7E8C,
                dark: 0x7C00,
                darkest: 0x0000
            )
        )
        XCTAssertEqual(
            GBCCompatibilityPalette.red,
            GBCCompatibilityPalette(
                lightest: 0x7FFF,
                light: 0x421F,
                dark: 0x1CF2,
                darkest: 0x0000
            )
        )
    }

    @MainActor
    func testAppearanceModesExposeExpectedColorSchemeOverride() {
        XCTAssertNil(AppearanceMode.system.preferredColorScheme)
        XCTAssertEqual(AppearanceMode.light.preferredColorScheme, .light)
        XCTAssertEqual(AppearanceMode.dark.preferredColorScheme, .dark)

        let theme = GameBoyTheme(appearanceMode: .system, persistsChanges: false)
        theme.systemColorScheme = .dark
        XCTAssertTrue(theme.isDark)
        theme.systemColorScheme = .light
        XCTAssertFalse(theme.isDark)
    }

    @MainActor
    func testThemeDefaultsToRedAndSystemAppearance() throws {
        let suiteName = "jellyboy-theme-defaults-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let theme = GameBoyTheme(persistsChanges: true, defaults: defaults)

        XCTAssertEqual(theme.gameVersion, .red)
        XCTAssertEqual(theme.appearanceMode, .system)
    }

    @MainActor
    func testGameVersionPersists() throws {
        let suiteName = "jellyboy-game-version-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let theme = GameBoyTheme(persistsChanges: true, defaults: defaults)
        theme.gameVersion = .red

        XCTAssertEqual(GameBoyTheme(persistsChanges: true, defaults: defaults).gameVersion, .red)
    }

    func testServerNormalizationAddsHTTPForLocalServers() throws {
        let url = try JellyfinClient.normalizeServer("192.168.1.5:8096/")
        XCTAssertEqual(url.absoluteString, "http://192.168.1.5:8096")
    }

    func testServerNormalizationDropsCredentialsQueryAndFragment() throws {
        let url = try JellyfinClient.normalizeServer(
            "https://person:secret@media.example/jellyfin/?api_key=secret#player"
        )
        XCTAssertEqual(url.absoluteString, "https://media.example/jellyfin")
    }

    func testRecentServersAreNormalizedDeduplicatedAndCapped() {
        let history = [
            "one.local:8096/",
            "http://ONE.local:8096",
            "https://two.example/?api_key=secret",
            "not a server",
            "three.local",
            "four.local",
            "five.local",
            "six.local",
        ]

        XCTAssertEqual(
            RecentServerHistory.sanitized(history),
            [
                "http://one.local:8096",
                "https://two.example",
                "http://three.local",
            ]
        )
    }

    func testRecentlyUsedServerMovesToTheFrontWithoutCredentials() {
        let history = RecentServerHistory.adding(
            "https://person:secret@two.example/jellyfin?token=secret",
            to: ["http://one.local:8096", "https://two.example/jellyfin"]
        )

        XCTAssertEqual(
            history,
            ["https://two.example/jellyfin", "http://one.local:8096"]
        )
        XCTAssertFalse(history.joined().contains("secret"))
        XCTAssertFalse(history.joined().contains("person"))
    }

    @MainActor
    func testStoredRecentServersAreSanitizedAndCanBeCleared() throws {
        let suiteName = "jellyboy-recent-server-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(
            ["https://person:secret@media.example/?token=secret"],
            forKey: "jellyboy.recent-servers"
        )

        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("jellyboy-recent-server-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = AppStore(
            restoreSession: false,
            downloads: OfflineDownloadStore(rootURL: rootURL),
            userDefaults: defaults
        )

        XCTAssertEqual(store.recentServerURLs, ["https://media.example"])
        XCTAssertEqual(
            defaults.stringArray(forKey: "jellyboy.recent-servers"),
            ["https://media.example"]
        )

        store.clearRecentServers()
        XCTAssertTrue(store.recentServerURLs.isEmpty)
        XCTAssertNil(defaults.stringArray(forKey: "jellyboy.recent-servers"))
    }

    func testEndpointPreservesJellyfinBasePath() throws {
        let baseURL = try JellyfinClient.normalizeServer("https://media.example/jellyfin/")
        let client = JellyfinClient(baseURL: baseURL, deviceID: "test-device")
        let endpoint = client.endpointURL(path: "Items")
        XCTAssertEqual(endpoint?.absoluteString, "https://media.example/jellyfin/Items")
    }

    func testPlaybackRequestAdvertisesDirectPlayAndTranscodeFallback() throws {
        let request = PlaybackInfoRequest(
            userID: "user-id",
            startTimeTicks: 10_000_000,
            audioStreamIndex: 2,
            subtitleStreamIndex: nil,
            maxStreamingBitrate: PlaybackQuality.mbps10.maximumBitrate,
            deviceProfile: .jellyboy(maximumBitrate: PlaybackQuality.mbps10.maximumBitrate),
            enableDirectPlay: true
        )
        let data = try JSONEncoder().encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let profile = try XCTUnwrap(object["DeviceProfile"] as? [String: Any])

        XCTAssertEqual(object["EnableDirectPlay"] as? Bool, true)
        XCTAssertEqual(object["EnableDirectStream"] as? Bool, true)
        XCTAssertEqual(object["AutoOpenLiveStream"] as? Bool, true)
        XCTAssertEqual(object["EnableTranscoding"] as? Bool, true)
        XCTAssertEqual(object["MaxStreamingBitrate"] as? Int, 10_000_000)
        let directPlayProfiles = profile["DirectPlayProfiles"] as? [[String: Any]] ?? []
        XCTAssertFalse(directPlayProfiles.isEmpty)
        XCTAssertNil(directPlayProfiles.first?["Container"])
        XCTAssertFalse((profile["TranscodingProfiles"] as? [[String: Any]] ?? []).isEmpty)
        XCTAssertFalse((profile["CodecProfiles"] as? [[String: Any]] ?? []).isEmpty)
        let subtitleProfiles = profile["SubtitleProfiles"] as? [[String: Any]] ?? []
        XCTAssertTrue(
            subtitleProfiles.contains {
                $0["Format"] as? String == "pgssub" && $0["Method"] as? String == "Embed"
            }
        )
        XCTAssertFalse(
            subtitleProfiles.contains {
                $0["Format"] as? String == "pgssub" && $0["Method"] as? String == "External"
            }
        )
        XCTAssertEqual(PlaybackQuality.maximum.maximumBitrate, 360_000_000)
    }

    func testMediaItemDecodesJellyfinPascalCasePayload() throws {
        let data = Data(
            #"{"Items":[{"Id":"abc","Name":"Moon Harbor","Type":"Movie","ProductionYear":1989,"RunTimeTicks":65400000000,"ImageTags":{"Primary":"tag"},"UserData":{"PlayedPercentage":25,"PlaybackPositionTicks":10000000}}]}"#
                .utf8
        )
        let result = try JSONDecoder().decode(ItemQueryResult.self, from: data)
        let item = try XCTUnwrap(result.items.first)

        XCTAssertEqual(item.id, "abc")
        XCTAssertEqual(item.imageTag, "tag")
        XCTAssertEqual(item.progress, 0.25, accuracy: 0.001)
        XCTAssertEqual(item.durationText, "1H 49M")
    }

    func testLibrariesUseTheSignedInUsersJellyfinViews() async throws {
        let client = makeStubbedClient(
            returning:
                #"{"Items":[{"Id":"movies-id","Name":"Family Movies","CollectionType":"movies"},{"Id":"shows-id","Name":"TV Shows","CollectionType":"tvshows"}]}"#
        )

        let libraries = try await client.libraries(userID: "user-id")
        let request = try XCTUnwrap(JellyfinURLProtocolStub.lastRequest)
        let components = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))

        XCTAssertEqual(components.path, "/Users/user-id/Views")
        XCTAssertTrue(
            components.queryItems?.contains(URLQueryItem(name: "includeExternalContent", value: "false")) == true
        )
        XCTAssertEqual(libraries.map(\.name), ["Family Movies", "TV Shows"])
        XCTAssertEqual(libraries.map(\.collectionType), ["movies", "tvshows"])
    }

    func testLibraryItemsStayInsideTheSelectedServerLibrary() async throws {
        let client = makeStubbedClient(
            returning: #"{"Items":[{"Id":"series-id","Name":"Tiny Signals","Type":"Series"}]}"#
        )
        let library = MediaLibrary(id: "shows-id", name: "TV Shows", collectionType: "tvshows")

        let items = try await client.items(in: library, userID: "user-id")
        let request = try XCTUnwrap(JellyfinURLProtocolStub.lastRequest)
        let components = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))

        XCTAssertEqual(components.path, "/Items")
        XCTAssertTrue(components.queryItems?.contains(URLQueryItem(name: "parentId", value: "shows-id")) == true)
        XCTAssertTrue(components.queryItems?.contains(URLQueryItem(name: "includeItemTypes", value: "Series")) == true)
        XCTAssertEqual(items.map(\.id), ["series-id"])
    }

    func testMediaKindDistinguishesEpisodesAndLiveChannels() {
        let episode = MediaItem(id: "episode", name: "Episode", type: "episode")
        let channel = MediaItem(id: "channel", name: "Channel", type: "tvchannel")

        XCTAssertTrue(episode.isEpisode)
        XCTAssertEqual(episode.mediaKind, "EPISODE")
        XCTAssertEqual(channel.mediaKind, "LIVE TV")
    }

    func testMediaGridFitsTwoCardsInsideACompactPhoneViewport() {
        let metrics = MediaGridMetrics(availableWidth: 361)

        XCTAssertEqual(metrics.columnCount, 2)
        XCTAssertEqual(metrics.itemWidth, 173.5, accuracy: 0.001)
        XCTAssertEqual(
            metrics.itemWidth * CGFloat(metrics.columnCount)
                + MediaGridMetrics.spacing * CGFloat(metrics.columnCount - 1),
            361,
            accuracy: 0.001
        )
    }

    func testMediaGridKeepsCardsWithinItsMaximumWidth() {
        let metrics = MediaGridMetrics(availableWidth: 1_100)

        XCTAssertGreaterThan(metrics.columnCount, 2)
        XCTAssertLessThanOrEqual(metrics.itemWidth, MediaGridMetrics.maximumItemWidth)
    }

    func testPlaybackSourceChoosesNativeOnlyForAppleContainers() throws {
        let mp4Data = Data(
            #"{"Id":"source","Container":"mp4","SupportsDirectPlay":true,"MediaStreams":[{"Index":0,"Type":"Video","Codec":"h264"},{"Index":1,"Type":"Audio","Codec":"aac","Language":"eng","IsDefault":true}]}"#
                .utf8
        )
        let mkvData = Data(
            #"{"Id":"source","Container":"mkv","SupportsDirectPlay":true,"MediaStreams":[{"Index":0,"Type":"Video","Codec":"hevc"},{"Index":1,"Type":"Audio","Codec":"dts"}]}"#
                .utf8
        )

        let mp4 = try JSONDecoder().decode(PlaybackMediaSource.self, from: mp4Data)
        let mkv = try JSONDecoder().decode(PlaybackMediaSource.self, from: mkvData)

        XCTAssertTrue(mp4.isNativeApplePlayback)
        XCTAssertFalse(mkv.isNativeApplePlayback)
        XCTAssertEqual(mp4.audioStreams.first?.menuTitle, "ENG")
        XCTAssertEqual(mp4.audioStreams.first?.selectorTitle, "ENG // AAC")
    }

    func testDirectPlaybackUsesTheJellyfinAudioEndpointForMusic() {
        XCTAssertEqual(
            JellyfinClient.directPlaybackPath(itemID: "song-id", isAudio: true),
            "Audio/song-id/stream"
        )
        XCTAssertEqual(
            JellyfinClient.directPlaybackPath(itemID: "movie-id", isAudio: false),
            "Videos/movie-id/stream"
        )
    }

    func testPlaybackUsesDirectStreamBeforeFullTranscode() async throws {
        let client = makeStubbedClient(
            returning:
                #"{"MediaSources":[{"Id":"source","Container":"mkv","Bitrate":5000000,"SupportsDirectPlay":false,"SupportsDirectStream":true,"SupportsTranscoding":true,"TranscodingUrl":"/Videos/movie/master.m3u8","MediaStreams":[{"Index":0,"Type":"Video","Codec":"h264"},{"Index":1,"Type":"Audio","Codec":"aac"}]}],"PlaySessionId":"play-session"}"#
        )

        let plan = try await client.playbackPlan(
            for: MediaItem(id: "movie", name: "Movie", type: "Movie"),
            userID: "user",
            quality: .maximum
        )

        XCTAssertEqual(plan.method, .directStream)
        XCTAssertEqual(plan.engine, .native)
        XCTAssertTrue(plan.url.absoluteString.contains("master.m3u8"))
    }

    func testLiveTVDirectSourceUsesVLCBeforeServerTranscode() async throws {
        let client = makeStubbedClient(
            returning:
                #"{"MediaSources":[{"Id":"live-source","Path":"https://tuner.example/channel.ts","Container":"mpegts","SupportsDirectPlay":true,"SupportsDirectStream":true,"SupportsTranscoding":true,"TranscodingUrl":"/Videos/channel/master.m3u8","LiveStreamId":"live-id","MediaStreams":[{"Index":0,"Type":"Video","Codec":"mpeg2video"},{"Index":1,"Type":"Audio","Codec":"ac3"}]}]}"#
        )

        let plan = try await client.playbackPlan(
            for: MediaItem(id: "channel", name: "Channel", type: "TvChannel"),
            userID: "user",
            quality: .maximum
        )

        XCTAssertEqual(plan.method, .directPlay)
        XCTAssertEqual(plan.engine, .vlc)
        XCTAssertEqual(plan.url.absoluteString, "https://tuner.example/channel.ts")
    }

    func testLiveTVURLOnDifferentPortDoesNotReceiveJellyfinToken() async throws {
        let client = makeStubbedClient(
            returning:
                #"{"MediaSources":[{"Id":"live-source","Path":"https://media.example:8443/channel.ts","SupportsDirectPlay":true}]}"#,
            accessToken: "private-token"
        )

        let plan = try await client.playbackPlan(
            for: MediaItem(id: "channel", name: "Channel", type: "TvChannel"),
            userID: "user",
            quality: .maximum
        )

        XCTAssertEqual(plan.url.absoluteString, "https://media.example:8443/channel.ts")
        XCTAssertFalse(plan.url.absoluteString.contains("private-token"))
    }

    func testServerFallbackDisablesDirectPlayAndUsesTranscode() async throws {
        let client = makeStubbedClient(
            returning:
                #"{"MediaSources":[{"Id":"source","Container":"mkv","SupportsDirectPlay":true,"SupportsDirectStream":false,"SupportsTranscoding":true,"TranscodingUrl":"/Videos/movie/master.m3u8","MediaStreams":[{"Index":0,"Type":"Video","Codec":"h264"}]}]}"#
        )

        let plan = try await client.playbackPlan(
            for: MediaItem(id: "movie", name: "Movie", type: "Movie"),
            userID: "user",
            quality: .maximum,
            allowDirectPlay: false
        )
        let body = try XCTUnwrap(JellyfinURLProtocolStub.lastRequestBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertEqual(object["EnableDirectPlay"] as? Bool, false)
        XCTAssertEqual(plan.method, .transcode)
        XCTAssertEqual(plan.engine, .native)
    }

    func testPlaybackSkipsUnplayableFirstMediaSource() async throws {
        let client = makeStubbedClient(
            returning:
                #"{"MediaSources":[{"Id":"broken","Container":"mkv","SupportsDirectPlay":false,"SupportsDirectStream":false,"SupportsTranscoding":false},{"Id":"working","Container":"mkv","SupportsDirectPlay":true,"SupportsDirectStream":false,"SupportsTranscoding":false,"MediaStreams":[{"Index":0,"Type":"Video","Codec":"h264"}]}]}"#
        )

        let plan = try await client.playbackPlan(
            for: MediaItem(id: "movie", name: "Movie", type: "Movie"),
            userID: "user",
            quality: .maximum
        )

        XCTAssertEqual(plan.source.id, "working")
        XCTAssertEqual(plan.method, .directPlay)
        XCTAssertEqual(plan.engine, .vlc)
    }

    func testPlaybackKeepsTheSourceContainingTheSelectedAudioTrack() async throws {
        let client = makeStubbedClient(
            returning:
                #"{"MediaSources":[{"Id":"version-a","Container":"mkv","SupportsDirectPlay":true,"MediaStreams":[{"Index":1,"Type":"Audio","Codec":"aac"}]},{"Id":"version-b","Container":"mkv","SupportsDirectPlay":true,"MediaStreams":[{"Index":7,"Type":"Audio","Codec":"ac3"}]}]}"#
        )

        let plan = try await client.playbackPlan(
            for: MediaItem(id: "movie", name: "Movie", type: "Movie"),
            userID: "user",
            quality: .maximum,
            audioStreamIndex: 7
        )

        XCTAssertEqual(plan.source.id, "version-b")
        XCTAssertEqual(plan.source.audioStreams.first?.index, 7)
    }

    func testLimitedQualityNeverFallsBackToOversizedDirectPlay() async throws {
        let client = makeStubbedClient(
            returning:
                #"{"MediaSources":[{"Id":"source","Container":"mkv","Bitrate":8000000,"SupportsDirectPlay":true,"SupportsDirectStream":false,"SupportsTranscoding":false}]}"#
        )

        do {
            _ = try await client.playbackPlan(
                for: MediaItem(id: "movie", name: "Movie", type: "Movie"),
                userID: "user",
                quality: .mbps2
            )
            XCTFail("Expected an oversized source without transcoding to be rejected")
        } catch JellyfinError.noPlayableStream {
            // Expected: never ignore the user's selected bandwidth limit.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testExternalTranscodeURLDoesNotReceiveJellyfinToken() async throws {
        let client = makeStubbedClient(
            returning:
                #"{"MediaSources":[{"Id":"source","SupportsTranscoding":true,"TranscodingUrl":"https://cdn.example/video.mp4?signed=1"}]}"#,
            accessToken: "private-token"
        )

        let plan = try await client.playbackPlan(
            for: MediaItem(id: "movie", name: "Movie", type: "Movie"),
            userID: "user",
            quality: .maximum
        )

        XCTAssertEqual(plan.url.absoluteString, "https://cdn.example/video.mp4?signed=1")
        XCTAssertFalse(plan.url.absoluteString.contains("private-token"))
    }

    func testAbsoluteSameOriginTranscodeURLReceivesJellyfinToken() async throws {
        let client = makeStubbedClient(
            returning:
                #"{"MediaSources":[{"Id":"source","SupportsTranscoding":true,"TranscodingUrl":"https://media.example/video.mp4"}]}"#
        )

        let plan = try await client.playbackPlan(
            for: MediaItem(id: "movie", name: "Movie", type: "Movie"),
            userID: "user",
            quality: .maximum
        )

        XCTAssertEqual(
            URLComponents(url: plan.url, resolvingAgainstBaseURL: false)?.queryItems,
            [URLQueryItem(name: "api_key", value: "token")]
        )
    }

    func testMaximumQualityOfflineDownloadAcceptsServerRemux() async throws {
        let client = makeStubbedClient(
            returning:
                #"{"MediaSources":[{"Id":"source","Container":"mkv","Bitrate":5000000,"SupportsDirectPlay":false,"SupportsDirectStream":true,"SupportsTranscoding":false,"TranscodingUrl":"/Videos/movie/remux.mp4","MediaStreams":[{"Index":0,"Type":"Video","Codec":"h264"},{"Index":1,"Type":"Audio","Codec":"aac"}]}]}"#
        )

        let preparation = try await client.offlinePreparation(
            for: MediaItem(id: "movie", name: "Movie", type: "Movie"),
            userID: "user",
            options: OfflineDownloadOptions(
                quality: .maximum,
                audioStreamIndex: 1,
                subtitleStreamIndex: nil
            )
        )

        XCTAssertEqual(preparation.engine, .native)
        XCTAssertEqual(preparation.mediaFileExtension, "mp4")
        XCTAssertTrue(preparation.downloadURL.absoluteString.contains("remux.mp4"))
    }

    func testOfflineChoicesSkipUndownloadableFirstSource() async throws {
        let client = makeStubbedClient(
            returning:
                #"{"MediaSources":[{"Id":"broken"},{"Id":"downloadable","Container":"mkv","SupportsDirectPlay":true}]}"#
        )

        let source = try await client.offlineChoices(
            for: MediaItem(id: "movie", name: "Movie", type: "Movie"),
            userID: "user"
        )

        XCTAssertEqual(source.id, "downloadable")
    }

    func testOfflineImageSubtitleForcesProgressiveTranscode() async throws {
        let client = makeStubbedClient(
            returning:
                #"{"MediaSources":[{"Id":"source","Container":"mkv","SupportsDirectPlay":true,"SupportsTranscoding":true,"TranscodingUrl":"/Videos/movie/download.mp4","MediaStreams":[{"Index":1,"Type":"Audio","Codec":"aac"},{"Index":4,"Type":"Subtitle","Codec":"pgssub"}]}]}"#
        )

        let preparation = try await client.offlinePreparation(
            for: MediaItem(id: "movie", name: "Movie", type: "Movie"),
            userID: "user",
            options: OfflineDownloadOptions(
                quality: .maximum,
                audioStreamIndex: 1,
                subtitleStreamIndex: 4
            )
        )
        let body = try XCTUnwrap(JellyfinURLProtocolStub.lastRequestBody)
        let request = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertEqual(preparation.engine, .native)
        XCTAssertEqual(preparation.mediaFileExtension, "mp4")
        XCTAssertNil(preparation.subtitleURL)
        XCTAssertEqual(request["AudioStreamIndex"] as? Int, 1)
        XCTAssertEqual(request["SubtitleStreamIndex"] as? Int, 4)
    }

    func testOfflineTextSubtitleIsSavedSeparatelyForVLC() async throws {
        let client = makeStubbedClient(
            returning:
                #"{"MediaSources":[{"Id":"source","Container":"mp4","SupportsDirectPlay":true,"MediaStreams":[{"Index":1,"Type":"Audio","Codec":"aac"},{"Index":3,"Type":"Subtitle","Codec":"subrip","IsExternal":true}]}]}"#
        )

        let preparation = try await client.offlinePreparation(
            for: MediaItem(id: "movie", name: "Movie", type: "Movie"),
            userID: "user",
            options: OfflineDownloadOptions(
                quality: .maximum,
                audioStreamIndex: 1,
                subtitleStreamIndex: 3
            )
        )

        XCTAssertEqual(preparation.engine, .vlc)
        XCTAssertEqual(
            preparation.subtitleURL?.path,
            "/Videos/movie/source/Subtitles/3/Stream.vtt"
        )
        XCTAssertEqual(
            URLComponents(url: try XCTUnwrap(preparation.subtitleURL), resolvingAgainstBaseURL: false)?
                .queryItems,
            [URLQueryItem(name: "api_key", value: "token")]
        )
    }

    func testOfflineProfileUsesProgressiveHTTPTranscodes() throws {
        let profile = PlaybackDeviceProfile.offlineDownload(maximumBitrate: 5_000_000)
        let data = try JSONEncoder().encode(profile)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let profiles = try XCTUnwrap(object["TranscodingProfiles"] as? [[String: Any]])

        XCTAssertTrue(
            profiles.contains {
                $0["Type"] as? String == "Video"
                    && $0["Container"] as? String == "mp4"
                    && $0["Protocol"] as? String == "http"
            })
        XCTAssertTrue(
            profiles.contains {
                $0["Type"] as? String == "Audio"
                    && $0["Container"] as? String == "mp3"
                    && $0["Protocol"] as? String == "http"
            })

        let subtitleProfiles = try XCTUnwrap(object["SubtitleProfiles"] as? [[String: Any]])
        XCTAssertTrue(
            subtitleProfiles.contains {
                $0["Format"] as? String == "pgssub" && $0["Method"] as? String == "Encode"
            })
    }

    func testOfflineSubtitleUsesJellyfinVTTStreamRoute() {
        XCTAssertEqual(
            JellyfinClient.subtitleStreamPath(
                itemID: "movie-id",
                mediaSourceID: "source-id",
                streamIndex: 4
            ),
            "Videos/movie-id/source-id/Subtitles/4/Stream.vtt"
        )
    }

    func testOfflineManifestSourceDropsNetworkCredentialsAndURLs() throws {
        let data = Data(
            #"{"Id":"source","Path":"/secret/source.mkv","Container":"mkv","SupportsDirectPlay":true,"SupportsTranscoding":true,"TranscodingUrl":"/secret/transcode?api_key=token","RequiredHttpHeaders":{"Authorization":"secret"},"MediaStreams":[]}"#
                .utf8
        )
        let source = try JSONDecoder().decode(PlaybackMediaSource.self, from: data)
        let sanitized = source.sanitizedForOfflineStorage

        XCTAssertNil(sanitized.transcodingURL)
        XCTAssertNil(sanitized.requiredHTTPHeaders)
        XCTAssertNil(sanitized.path)
        XCTAssertEqual(sanitized.id, "source")
        XCTAssertEqual(sanitized.container, "mkv")
    }

    func testQualityOptionsMatchOfficialJellyfinBitrateLadders() throws {
        XCTAssertEqual(
            PlaybackQuality.options(for: nil, audioOnly: false),
            [
                .maximum, .mbps120, .mbps80, .mbps60, .mbps40, .mbps20, .mbps15,
                .mbps10, .mbps8, .mbps6, .mbps4, .mbps3, .kbps1500, .kbps720, .kbps420,
            ]
        )
        XCTAssertEqual(
            PlaybackQuality.options(for: nil, audioOnly: true),
            [
                .maximum, .mbps2, .kbps1500, .mbps1, .kbps320,
                .kbps256, .kbps192, .kbps128, .kbps96, .kbps64,
            ]
        )

        let source = try JSONDecoder().decode(
            PlaybackMediaSource.self,
            from: Data(#"{"Bitrate":10000000,"MediaStreams":[{"Index":0,"Type":"Video"}]}"#.utf8)
        )
        let filteredOptions = PlaybackQuality.options(for: source)
        XCTAssertTrue(filteredOptions.contains(.maximum))
        XCTAssertTrue(filteredOptions.contains(.mbps10))
        XCTAssertFalse(filteredOptions.contains(.mbps15))
    }

    @MainActor
    func testClearAllRemovesDownloadedMediaAndManifestEntry() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("jellyboy-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        let sourceData = Data(
            #"{"Id":"source","Container":"mp4","SupportsDirectPlay":true,"MediaStreams":[]}"#.utf8
        )
        let source = try JSONDecoder().decode(PlaybackMediaSource.self, from: sourceData)
        let record = OfflineDownload(
            id: UUID(),
            item: MediaItem(id: "movie", name: "Movie", type: "Movie"),
            quality: .maximum,
            source: source,
            engine: .native,
            selectedAudioIndex: nil,
            selectedSubtitleIndex: nil,
            mediaFilename: "media.mp4",
            subtitleFilename: nil,
            posterFilename: nil,
            byteCount: 3,
            createdAt: Date()
        )
        let recordDirectory = record.directoryURL(in: rootURL)
        try FileManager.default.createDirectory(at: recordDirectory, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: record.mediaURL(in: rootURL))
        try JSONEncoder().encode([record]).write(
            to: rootURL.appendingPathComponent("manifest.json"),
            options: .atomic
        )

        let store = OfflineDownloadStore(rootURL: rootURL)
        XCTAssertEqual(store.records.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: recordDirectory.path))

        store.clearAll()

        XCTAssertTrue(store.records.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: recordDirectory.path))
        let manifest = try Data(contentsOf: rootURL.appendingPathComponent("manifest.json"))
        XCTAssertEqual(try JSONDecoder().decode([OfflineDownload].self, from: manifest), [])
    }

    @MainActor
    func testDownloadContainerIsMigratedToLowercaseName() throws {
        let parentURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("jellyboy-case-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: parentURL) }
        try FileManager.default.createDirectory(at: parentURL, withIntermediateDirectories: true)

        let oldURL = parentURL.appendingPathComponent("jellyboy".uppercased(), isDirectory: true)
        let newURL = parentURL.appendingPathComponent("jellyboy", isDirectory: true)
        try FileManager.default.createDirectory(at: oldURL, withIntermediateDirectories: true)
        try Data([1]).write(to: oldURL.appendingPathComponent("marker"))

        OfflineDownloadStore.normalizeContainerName(in: parentURL, to: newURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: newURL.appendingPathComponent("marker").path))
        let names = try FileManager.default.contentsOfDirectory(atPath: parentURL.path)
        XCTAssertTrue(names.contains("jellyboy"))
        XCTAssertFalse(names.contains("jellyboy".uppercased()))
    }

    private func makeStubbedClient(
        returning response: String,
        accessToken: String = "token"
    ) -> JellyfinClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [JellyfinURLProtocolStub.self]
        JellyfinURLProtocolStub.responseData = Data(response.utf8)
        addTeardownBlock { JellyfinURLProtocolStub.reset() }

        return JellyfinClient(
            baseURL: URL(string: "https://media.example")!,
            accessToken: accessToken,
            deviceID: "device",
            urlSession: URLSession(configuration: configuration)
        )
    }
}

private final class JellyfinURLProtocolStub: URLProtocol {
    nonisolated(unsafe) static var responseData = Data()
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var lastRequestBody: Data?

    static func reset() {
        responseData = Data()
        lastRequest = nil
        lastRequestBody = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        Self.lastRequestBody = request.httpBody ?? request.httpBodyStream.flatMap(Self.read)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func read(_ stream: InputStream) -> Data? {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count >= 0 else { return nil }
            if count == 0 { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }
}
