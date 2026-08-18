import AVFoundation
import AVKit
import Foundation
import Observation
@preconcurrency import VLCKit

#if os(iOS)
    import MediaPlayer
#endif

@MainActor
@Observable
final class PlaybackCoordinator: NSObject, @preconcurrency VLCMediaPlayerDelegate {
    enum State: Equatable {
        case idle
        case loading
        case ready
        case failed(String)
    }

    var state: State = .idle
    var plan: PlaybackPlan?
    var quality: PlaybackQuality = .maximum
    var selectedAudioIndex: Int?
    var selectedSubtitleIndex: Int?
    var speed: Float = 1
    var isPlaying = false
    private(set) var elapsedSeconds: Double = 0
    private(set) var offlineQualityTitle: String?

    @ObservationIgnored private(set) var avPlayer: AVPlayer?
    @ObservationIgnored let vlcPlayer = VLCMediaPlayer()
    @ObservationIgnored private var item: MediaItem?
    @ObservationIgnored private weak var store: AppStore?
    @ObservationIgnored private var loadID = UUID()
    @ObservationIgnored private var pendingResumeMilliseconds: Int32?
    @ObservationIgnored private var offlineSubtitleURL: URL?
    @ObservationIgnored private var progressTask: Task<Void, Never>?
    @ObservationIgnored private var playbackReadinessTask: Task<Void, Never>?
    @ObservationIgnored private var usedServerFallback = false
    private var engineOverride: PlaybackEngine?
    #if os(iOS)
        @ObservationIgnored private var remoteCommandTargets: [(MPRemoteCommand, Any)] = []
    #endif

    override init() {
        super.init()
        vlcPlayer.delegate = self
        vlcPlayer.timeChangeUpdateInterval = 0.5
    }

    var activeEngine: PlaybackEngine? {
        if let engineOverride { return engineOverride }
        if selectedSubtitle?.isExternal == true, plan?.method == .directPlay {
            return .vlc
        }
        return plan?.engine
    }

    var audioStreams: [PlaybackMediaStream] { plan?.source.audioStreams ?? [] }
    var subtitleStreams: [PlaybackMediaStream] { plan?.source.subtitleStreams ?? [] }

    var selectedAudio: PlaybackMediaStream? {
        audioStreams.first { $0.index == selectedAudioIndex }
    }

    var selectedSubtitle: PlaybackMediaStream? {
        subtitleStreams.first { $0.index == selectedSubtitleIndex }
    }

    var methodLabel: String {
        guard let plan, let activeEngine else { return "PREPARING" }
        #if os(iOS)
            if avPlayer?.isExternalPlaybackActive == true { return "AIRPLAY // AV" }
        #endif
        let livePrefix = isLive ? "LIVE " : ""
        return "\(livePrefix)\(plan.method.rawValue) // \(activeEngine.rawValue)"
    }

    var isOffline: Bool { plan?.method == .offline }
    var isLive: Bool { item?.isLiveChannel == true }
    var qualityTitle: String { offlineQualityTitle ?? quality.title }

    func load(item: MediaItem, store: AppStore) async {
        self.item = item
        self.store = store
        selectedAudioIndex = nil
        selectedSubtitleIndex = nil
        offlineQualityTitle = nil
        offlineSubtitleURL = nil
        usedServerFallback = false
        engineOverride = nil
        await reload(preservingPosition: false)
    }

    func load(download: OfflineDownload, store: OfflineDownloadStore) {
        item = download.item
        self.store = nil
        quality = .maximum
        offlineQualityTitle = download.quality.title
        selectedAudioIndex = download.selectedAudioIndex
        selectedSubtitleIndex = download.selectedSubtitleIndex
        offlineSubtitleURL = store.subtitleURL(for: download)
        engineOverride = nil
        let localPlan = PlaybackPlan(
            url: store.mediaURL(for: download),
            source: download.source,
            engine: download.engine,
            method: .offline,
            quality: .maximum
        )
        plan = localPlan
        state = .loading
        let initialPosition = Double(download.item.resumeTicks) / 10_000_000
        if install(localPlan, position: initialPosition), activeEngine != .native {
            state = .ready
        }
    }

    func selectQuality(_ quality: PlaybackQuality) {
        guard quality != self.quality else { return }
        self.quality = quality
        usedServerFallback = false
        Task { await reload(preservingPosition: true) }
    }

    func selectAudio(_ stream: PlaybackMediaStream) {
        guard selectedAudioIndex != stream.index else { return }
        selectedAudioIndex = stream.index
        usedServerFallback = false

        if plan?.method == .transcode || plan?.method == .directStream {
            Task { await reload(preservingPosition: true) }
        } else {
            applyLocalTrackSelection()
        }
    }

    func selectSubtitle(_ stream: PlaybackMediaStream?) {
        guard selectedSubtitleIndex != stream?.index else { return }
        let previousWasExternal = selectedSubtitle?.isExternal == true
        selectedSubtitleIndex = stream?.index
        usedServerFallback = false
        let nextIsExternal = stream?.isExternal == true

        if plan?.method == .transcode || plan?.method == .directStream {
            Task { await reload(preservingPosition: true) }
        } else if previousWasExternal || nextIsExternal || activeEngine != plan?.engine {
            restartCurrentPlan(preservingPosition: true)
        } else {
            applyLocalTrackSelection()
        }
    }

    func setSpeed(_ speed: Float) {
        self.speed = speed
        avPlayer?.defaultRate = speed
        if avPlayer?.timeControlStatus == .playing {
            avPlayer?.rate = speed
        }
        vlcPlayer.rate = speed
        updateSystemPlaybackInfo()
    }

    func togglePlayPause() {
        if isPlaying {
            pausePlayback()
        } else {
            resumePlayback()
        }
    }

    func retry() {
        usedServerFallback = false
        if store != nil {
            Task { await reload(preservingPosition: true) }
        } else {
            restartCurrentPlan(preservingPosition: true)
        }
    }

    private func resumePlayback() {
        switch activeEngine {
        case .native:
            guard let avPlayer else { return }
            avPlayer.playImmediately(atRate: speed)
            isPlaying = true
        case .vlc:
            vlcPlayer.play()
            vlcPlayer.rate = speed
            isPlaying = true
        case nil:
            break
        }
        updateSystemPlaybackInfo()
    }

    private func pausePlayback() {
        switch activeEngine {
        case .native:
            avPlayer?.pause()
        case .vlc:
            vlcPlayer.pause()
        case nil:
            break
        }
        isPlaying = false
        updateSystemPlaybackInfo()
    }

    func skip(seconds: Double) {
        switch activeEngine {
        case .native:
            guard let avPlayer else { return }
            let target = max(avPlayer.currentTime().seconds + seconds, 0)
            avPlayer.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        case .vlc:
            let target = max(Double(vlcPlayer.time.intValue) + seconds * 1_000, 0)
            vlcPlayer.time = VLCTime(number: NSNumber(value: target))
        case nil:
            break
        }
    }

    func attachVLCDrawable(_ drawable: AnyObject) {
        if vlcPlayer.drawable as AnyObject? !== drawable {
            vlcPlayer.drawable = drawable
        }
    }

    func stop() {
        loadID = UUID()
        closeLiveStreamIfNeeded(plan?.source.liveStreamID)
        stopProgressUpdates()
        stopPlaybackReadinessUpdates()
        avPlayer?.pause()
        avPlayer = nil
        vlcPlayer.stop()
        vlcPlayer.media = nil
        plan = nil
        offlineQualityTitle = nil
        offlineSubtitleURL = nil
        usedServerFallback = false
        engineOverride = nil
        elapsedSeconds = 0
        isPlaying = false
        state = .idle
        #if os(iOS)
            clearSystemPlaybackInfo()
            removeRemoteCommandTargets()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    func mediaPlayerStateChanged(_ newState: VLCMediaPlayerState) {
        guard activeEngine == .vlc else { return }
        switch newState {
        case .playing:
            isPlaying = true
            vlcPlayer.rate = speed
            if let pendingResumeMilliseconds {
                vlcPlayer.time = VLCTime(number: NSNumber(value: pendingResumeMilliseconds))
                self.pendingResumeMilliseconds = nil
            }
            applyVLCTrackSelection()
            updateSystemPlaybackInfo()
        case .paused, .stopped, .stopping:
            isPlaying = false
            updateSystemPlaybackInfo()
        case .error:
            failPlayback("THE PLAYER COULDN'T DECODE THIS FILE.")
        default:
            break
        }
    }

    func mediaPlayerTrackAdded(_ trackId: String, with trackType: VLCMedia.TrackType) {
        guard activeEngine == .vlc else { return }
        guard trackType == .audio || trackType == .text else { return }
        applyVLCTrackSelection()
    }

    private func reload(preservingPosition: Bool, allowDirectPlay: Bool = true) async {
        guard let item, let store else { return }
        let position = preservingPosition ? currentPositionSeconds : nil
        let thisLoadID = UUID()
        loadID = thisLoadID
        state = .loading

        do {
            let nextPlan = try await store.playbackPlan(
                for: item,
                quality: quality,
                audioStreamIndex: selectedAudioIndex,
                subtitleStreamIndex: selectedSubtitleIndex,
                allowDirectPlay: allowDirectPlay
            )
            guard loadID == thisLoadID, !Task.isCancelled else {
                if let liveStreamID = nextPlan.source.liveStreamID {
                    await store.closeLiveStream(liveStreamID)
                }
                return
            }

            if plan?.source.liveStreamID != nextPlan.source.liveStreamID {
                closeLiveStreamIfNeeded(plan?.source.liveStreamID)
            }
            engineOverride = nil
            plan = nextPlan
            if selectedAudioIndex == nil {
                selectedAudioIndex =
                    nextPlan.source.audioStreams.first(where: \.isDefault)?.index
                    ?? nextPlan.source.audioStreams.first?.index
            }
            if selectedSubtitleIndex == nil {
                selectedSubtitleIndex =
                    nextPlan.source.subtitleStreams.first(where: { $0.isForced || $0.isDefault })?.index
            }

            let initialPosition = Double(item.resumeTicks) / 10_000_000
            if install(nextPlan, position: position ?? initialPosition), activeEngine != .native {
                state = .ready
            }
        } catch is CancellationError {
            return
        } catch {
            guard loadID == thisLoadID else { return }
            state = .failed(
                (error as? LocalizedError)?.errorDescription ?? "PLAYBACK COULDN'T START."
            )
        }
    }

    private func restartCurrentPlan(preservingPosition: Bool) {
        guard let plan else { return }
        let position = preservingPosition ? currentPositionSeconds : 0
        if install(plan, position: position), activeEngine != .native {
            state = .ready
        }
    }

    @discardableResult
    private func install(_ plan: PlaybackPlan, position: Double) -> Bool {
        activatePlaybackAudioSession()
        stopProgressUpdates()
        stopPlaybackReadinessUpdates()
        state = .loading
        avPlayer?.pause()
        avPlayer = nil
        vlcPlayer.stop()
        vlcPlayer.media = nil
        isPlaying = false

        switch activeEngine ?? plan.engine {
        case .native:
            let asset = AVURLAsset(
                url: plan.url,
                options: plan.source.requiredHTTPHeaders.map {
                    ["AVURLAssetHTTPHeaderFieldsKey": $0]
                }
            )
            let playerItem = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: playerItem)
            player.allowsExternalPlayback = true
            #if os(iOS)
                player.usesExternalPlaybackWhileExternalScreenIsActive = true
            #endif
            player.defaultRate = speed
            avPlayer = player
            if position > 0 {
                player.seek(to: CMTime(seconds: position, preferredTimescale: 600))
            }
            player.playImmediately(atRate: speed)
            isPlaying = true
            Task { await applyNativeTrackSelection() }
            startProgressUpdates()
            startNativePlaybackReadinessUpdates(for: playerItem)
            installRemoteCommandTargetsIfNeeded()
            updateSystemPlaybackInfo()
            return true

        case .vlc:
            guard let media = VLCMedia(url: plan.url) else {
                state = .failed("THE PLAYER COULDN'T OPEN THIS FILE.")
                return false
            }
            media.addOption(":no-video-title-show")
            media.addOption(":avcodec-hw=videotoolbox")
            if let headerFields = plan.source.requiredHTTPHeaders {
                if let userAgent = headerFields["User-Agent"] {
                    media.addOption(":http-user-agent=\(userAgent)")
                }
                if let referer = headerFields["Referer"] {
                    media.addOption(":http-referrer=\(referer)")
                }
            }
            if let offlineSubtitleURL {
                media.addOption(":sub-file=\(offlineSubtitleURL.absoluteString)")
            } else if let selectedSubtitle,
                selectedSubtitle.isExternal,
                let deliveryURL = selectedSubtitle.deliveryURL,
                let subtitleURL = store?.playbackAssetURL(from: deliveryURL)
            {
                media.addOption(":sub-file=\(subtitleURL.absoluteString)")
            }
            vlcPlayer.media = media
            pendingResumeMilliseconds =
                position > 0
                ? Int32(clamping: Int(position * 1_000))
                : nil
            vlcPlayer.play()
            isPlaying = true
            startProgressUpdates()
            installRemoteCommandTargetsIfNeeded()
            updateSystemPlaybackInfo()
            return true
        }
    }

    private var currentPositionSeconds: Double {
        switch activeEngine {
        case .native:
            let seconds = avPlayer?.currentTime().seconds ?? 0
            return seconds.isFinite ? max(seconds, 0) : 0
        case .vlc:
            return max(Double(vlcPlayer.time.intValue) / 1_000, 0)
        case nil:
            return 0
        }
    }

    private func applyLocalTrackSelection() {
        switch activeEngine {
        case .native:
            Task { await applyNativeTrackSelection() }
        case .vlc:
            applyVLCTrackSelection()
        case nil:
            break
        }
    }

    private func applyVLCTrackSelection() {
        if let selectedAudioIndex,
            let streamIndex = audioStreams.firstIndex(where: { $0.index == selectedAudioIndex }),
            vlcPlayer.audioTracks.indices.contains(streamIndex)
        {
            vlcPlayer.audioTracks[streamIndex].isSelectedExclusively = true
        }

        guard offlineSubtitleURL == nil, selectedSubtitle?.isExternal != true else { return }
        guard let selectedSubtitleIndex else {
            vlcPlayer.deselectAllTextTracks()
            return
        }
        if let streamIndex = subtitleStreams.filter({ !$0.isExternal }).firstIndex(where: {
            $0.index == selectedSubtitleIndex
        }),
            vlcPlayer.textTracks.indices.contains(streamIndex)
        {
            vlcPlayer.textTracks[streamIndex].isSelectedExclusively = true
        }
    }

    private func applyNativeTrackSelection() async {
        guard let playerItem = avPlayer?.currentItem else { return }

        if let audioGroup = try? await playerItem.asset.loadMediaSelectionGroup(for: .audible),
            let selectedAudio
        {
            let option = matchingOption(for: selectedAudio, in: audioGroup)
            playerItem.select(option, in: audioGroup)
        }

        if let subtitleGroup = try? await playerItem.asset.loadMediaSelectionGroup(for: .legible) {
            if let selectedSubtitle, !selectedSubtitle.isExternal {
                playerItem.select(matchingOption(for: selectedSubtitle, in: subtitleGroup), in: subtitleGroup)
            } else {
                playerItem.select(nil, in: subtitleGroup)
            }
        }
    }

    private func matchingOption(
        for stream: PlaybackMediaStream,
        in group: AVMediaSelectionGroup
    ) -> AVMediaSelectionOption? {
        let normalizedLanguage = stream.language?.lowercased()
        let normalizedTitle = stream.menuTitle.lowercased()

        return group.options.first { option in
            let localeMatches =
                normalizedLanguage.map {
                    option.locale?.identifier.lowercased().hasPrefix($0) == true
                } ?? false
            let titleMatches =
                option.displayName.lowercased() == normalizedTitle
                || normalizedTitle.contains(option.displayName.lowercased())
            return localeMatches || titleMatches
        }
    }

    private func activatePlaybackAudioSession() {
        #if os(iOS)
            let audioSession = AVAudioSession.sharedInstance()
            try? audioSession.setCategory(
                .playback,
                mode: .moviePlayback,
                policy: .longFormVideo,
                options: []
            )
            try? audioSession.setActive(true)
        #endif
    }

    private func startProgressUpdates() {
        elapsedSeconds = currentPositionSeconds
        progressTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(2))
                } catch {
                    return
                }
                guard let self else { return }
                self.elapsedSeconds = self.currentPositionSeconds
                self.updateSystemPlaybackInfo()
            }
        }
    }

    private func stopProgressUpdates() {
        progressTask?.cancel()
        progressTask = nil
    }

    private func startNativePlaybackReadinessUpdates(for playerItem: AVPlayerItem) {
        playbackReadinessTask = Task { @MainActor [weak self, weak playerItem] in
            let clock = ContinuousClock()
            let deadline = clock.now + .seconds(25)

            while !Task.isCancelled {
                guard let self, let playerItem, self.avPlayer?.currentItem === playerItem else { return }
                switch playerItem.status {
                case .readyToPlay:
                    self.state = .ready
                    return
                case .failed:
                    self.failPlayback(
                        playerItem.error?.localizedDescription ?? "THE PLAYER COULDN'T OPEN THIS STREAM."
                    )
                    return
                case .unknown:
                    if clock.now >= deadline {
                        self.failPlayback(
                            self.isLive
                                ? "THIS CHANNEL DIDN'T SEND PLAYABLE VIDEO. TRY ANOTHER CHANNEL."
                                : "THE STREAM TOOK TOO LONG TO START. TRY AGAIN."
                        )
                        return
                    }
                @unknown default:
                    self.failPlayback("THE PLAYER RETURNED AN UNKNOWN STREAM STATE.")
                    return
                }

                do {
                    try await Task.sleep(for: .milliseconds(250))
                } catch {
                    return
                }
            }
        }
    }

    private func stopPlaybackReadinessUpdates() {
        playbackReadinessTask?.cancel()
        playbackReadinessTask = nil
    }

    private func failPlayback(_ message: String) {
        if activeEngine == .native, engineOverride == nil, plan != nil {
            engineOverride = .vlc
            restartCurrentPlan(preservingPosition: true)
            return
        }
        if plan?.method == .directPlay, store != nil, !usedServerFallback {
            usedServerFallback = true
            state = .loading
            Task { await reload(preservingPosition: true, allowDirectPlay: false) }
            return
        }
        avPlayer?.pause()
        isPlaying = false
        state = .failed(message.uppercased())
        closeLiveStreamIfNeeded(plan?.source.liveStreamID)
        updateSystemPlaybackInfo()
    }

    private func updateSystemPlaybackInfo() {
        #if os(iOS)
            guard let item, state != .idle else { return }
            var info: [String: Any] = [
                MPMediaItemPropertyTitle: item.name,
                MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsedSeconds,
                MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? speed : 0,
                MPNowPlayingInfoPropertyDefaultPlaybackRate: speed,
            ]
            if let seriesName = item.seriesName, !seriesName.isEmpty {
                info[MPMediaItemPropertyAlbumTitle] = seriesName
            }
            if let ticks = item.runTimeTicks, ticks > 0 {
                info[MPMediaItemPropertyPlaybackDuration] = Double(ticks) / 10_000_000
            }
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info

            let commands = MPRemoteCommandCenter.shared()
            commands.skipBackwardCommand.isEnabled = !isLive
            commands.skipForwardCommand.isEnabled = !isLive
            commands.changePlaybackPositionCommand.isEnabled = !isLive
        #endif
    }

    private func installRemoteCommandTargetsIfNeeded() {
        #if os(iOS)
            guard remoteCommandTargets.isEmpty else { return }
            let commands = MPRemoteCommandCenter.shared()
            commands.skipBackwardCommand.preferredIntervals = [10]
            commands.skipForwardCommand.preferredIntervals = [10]

            addRemoteTarget(to: commands.playCommand) { coordinator, _ in
                coordinator.resumePlayback()
            }
            addRemoteTarget(to: commands.pauseCommand) { coordinator, _ in
                coordinator.pausePlayback()
            }
            addRemoteTarget(to: commands.togglePlayPauseCommand) { coordinator, _ in
                coordinator.togglePlayPause()
            }
            addRemoteTarget(to: commands.skipBackwardCommand) { coordinator, event in
                let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 10
                coordinator.skip(seconds: -interval)
            }
            addRemoteTarget(to: commands.skipForwardCommand) { coordinator, event in
                let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 10
                coordinator.skip(seconds: interval)
            }
            addRemoteTarget(to: commands.changePlaybackPositionCommand) { coordinator, event in
                guard let event = event as? MPChangePlaybackPositionCommandEvent else { return }
                coordinator.seek(to: event.positionTime)
            }
        #endif
    }

    #if os(iOS)
        private func addRemoteTarget(
            to command: MPRemoteCommand,
            action: @escaping @MainActor (PlaybackCoordinator, MPRemoteCommandEvent) -> Void
        ) {
            let target = command.addTarget { [weak self] event in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    action(self, event)
                }
                return .success
            }
            remoteCommandTargets.append((command, target))
        }

        private func removeRemoteCommandTargets() {
            for (command, target) in remoteCommandTargets {
                command.removeTarget(target)
            }
            remoteCommandTargets.removeAll()
        }

        private func clearSystemPlaybackInfo() {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        }
    #endif

    private func seek(to seconds: Double) {
        let target = max(seconds, 0)
        switch activeEngine {
        case .native:
            avPlayer?.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        case .vlc:
            vlcPlayer.time = VLCTime(number: NSNumber(value: target * 1_000))
        case nil:
            break
        }
        elapsedSeconds = target
        updateSystemPlaybackInfo()
    }

    private func closeLiveStreamIfNeeded(_ liveStreamID: String?) {
        guard let liveStreamID, let store else { return }
        Task { await store.closeLiveStream(liveStreamID) }
    }
}
