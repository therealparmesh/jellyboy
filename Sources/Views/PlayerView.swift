import SwiftUI

struct PlayerView: View {
    let item: MediaItem
    let store: AppStore
    var offlineDownload: OfflineDownload? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(GameBoyTheme.self) private var theme
    @State private var coordinator = PlaybackCoordinator()
    @State private var activeSelector: PlayerSelectorKind?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if store.isDemo {
                demoPlayer
            } else {
                playbackSurface
                    .allowsHitTesting(false)
                    .zIndex(0)
            }

            playerChrome
                .zIndex(1)

            if let activeSelector {
                PixelChoiceMenu(
                    title: activeSelector.rawValue,
                    options: activeSelector.options(for: coordinator),
                    onSelect: {
                        activeSelector.select($0, coordinator: coordinator)
                        self.activeSelector = nil
                    },
                    onDismiss: { self.activeSelector = nil }
                )
                .zIndex(2)
            }
        }
        .task(id: offlineDownload?.id.uuidString ?? item.id) {
            guard !store.isDemo else { return }
            if let offlineDownload {
                coordinator.load(download: offlineDownload, store: store.downloads)
            } else {
                await coordinator.load(item: item, store: store)
            }
        }
        .onDisappear {
            coordinator.stop()
        }
    }

    @ViewBuilder
    private var playbackSurface: some View {
        switch coordinator.state {
        case .idle, .loading:
            Text("...")
                .font(.pixel(.title))
                .foregroundStyle(theme.panel)
                .accessibilityLabel("Loading player")

        case .ready:
            switch coordinator.activeEngine {
            case .native:
                if let player = coordinator.avPlayer {
                    NativePlayerSurface(player: player)
                        .ignoresSafeArea()
                }
            case .vlc:
                VLCPlayerSurface(coordinator: coordinator)
                    .ignoresSafeArea()
            case nil:
                EmptyView()
            }

        case .failed(let message):
            errorPanel(message)
        }
    }

    private var playerChrome: some View {
        VStack(spacing: 16) {
            topBar
            Spacer()

            if store.isDemo {
                demoControls
            } else if coordinator.state == .ready {
                liveControls
            }
        }
        .padding(16)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.name.uppercased())
                    .font(.pixel(.callout))
                    .lineLimit(1)
                Text(store.isDemo ? "SAMPLE // PREVIEW" : coordinator.methodLabel)
                    .font(.pixel(.caption2))
            }
            .foregroundStyle(theme.ink)
            .padding(.horizontal, 12)
            .frame(minHeight: 50)
            .background(theme.panel)
            .overlay { PixelFrame() }

            Spacer(minLength: 0)

            #if os(iOS)
                if !store.isDemo, coordinator.activeEngine == .native {
                    AirPlayRouteButton(color: theme.ink)
                        .frame(width: 46, height: 50)
                        .background(theme.panel)
                        .overlay { PixelFrame() }
                        .accessibilityLabel("AirPlay")
                }
            #endif

            Button {
                dismiss()
            } label: {
                Text("×")
                    .font(.pixel(.title))
                    .frame(width: 46, height: 50)
                    .foregroundStyle(theme.ink)
                    .background(theme.panel)
                    .overlay { PixelFrame() }
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("Close player")
            .accessibilityIdentifier("player.close")
        }
    }

    private var liveControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                if !coordinator.isLive {
                    playerButton("−10", accessibilityLabel: "Back 10 seconds") {
                        coordinator.skip(seconds: -10)
                    }
                }
                playerButton(coordinator.isPlaying ? "PAUSE" : "PLAY") {
                    coordinator.togglePlayPause()
                }
                if !coordinator.isLive {
                    playerButton("+10", accessibilityLabel: "Forward 10 seconds") {
                        coordinator.skip(seconds: 10)
                    }
                }
            }

            PlayerSelectorControls(coordinator: coordinator) {
                activeSelector = $0
            }

            if coordinator.plan?.method == .transcode {
                Text("SERVER TRANSCODING ACTIVE")
                    .font(.pixel(.caption2))
                    .foregroundStyle(theme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(theme.panel)
                    .overlay { PixelFrame() }
            }
        }
    }

    private func playerButton(
        _ title: String,
        accessibilityLabel: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PixelOutlineButtonStyle())
        .accessibilityLabel(accessibilityLabel ?? title)
    }

    private func errorPanel(_ message: String) -> some View {
        VStack(spacing: 18) {
            Text(message)
                .font(.pixel(.callout))
                .multilineTextAlignment(.center)
            Button("TRY AGAIN") { coordinator.retry() }
                .buttonStyle(PixelButtonStyle(fillsWidth: false))
        }
        .foregroundStyle(theme.ink)
        .padding(24)
        .background(theme.panel)
        .overlay { PixelFrame() }
        .padding(24)
    }

    private var demoPlayer: some View {
        VStack(spacing: 22) {
            JellySprite()
                .frame(width: 100, height: 100)
            Text("SAMPLE PLAYER")
                .font(.pixel(.title))
            Text("SAMPLE MODE PREVIEWS THE PLAYER WITHOUT VIDEO.")
                .font(.pixel(.callout))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(theme.ink)
        .padding(28)
        .background(theme.panel)
        .overlay { PixelFrame() }
        .padding(28)
    }

    private var demoControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                demoSelector("QUALITY", value: "MAXIMUM")
                demoSelector("AUDIO", value: "ENGLISH")
                demoSelector("SUBTITLES", value: "OFF")
                demoSelector("SPEED", value: "1×")
            }

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    demoSelector("QUALITY", value: "MAXIMUM")
                    demoSelector("SPEED", value: "1×")
                }
                HStack(spacing: 10) {
                    demoSelector("AUDIO", value: "ENGLISH")
                    demoSelector("SUBTITLES", value: "OFF")
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func demoSelector(_ title: String, value: String) -> some View {
        PixelSelectorLabel(title: title, value: value, showsDisclosure: false)
            .frame(minWidth: 92)
    }
}
