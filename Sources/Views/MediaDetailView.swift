import SwiftUI

struct MediaDetailView: View {
    let item: MediaItem
    let store: AppStore
    var offlineDownload: OfflineDownload? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(GameBoyTheme.self) private var theme
    @State private var playbackSelection: PlaybackSelection?
    @State private var downloadItem: MediaItem?
    @State private var showsClearConfirmation = false

    var body: some View {
        ZStack {
            theme.screen.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    #if os(iOS)
                        detailHeader
                    #endif
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 24) {
                            poster
                                .frame(width: 220)
                            facts
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        VStack(alignment: .leading, spacing: 18) {
                            poster
                                .frame(maxWidth: 240)
                                .frame(maxWidth: .infinity)
                            facts
                        }
                    }

                    if item.isSeries {
                        EpisodeListView(
                            series: item,
                            store: store,
                            onPlay: { playbackSelection = PlaybackSelection(item: $0) },
                            onDownload: { downloadItem = $0 }
                        )
                    }
                }
                .padding(18)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(item.name.uppercased())
        #if os(iOS)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        #endif
        #if os(iOS)
            .fullScreenCover(item: $playbackSelection) { selection in
                PlayerView(
                    item: selection.item,
                    store: store,
                    offlineDownload: selection.offlineDownload
                )
                .environment(theme)
            }
        #elseif os(macOS)
            .sheet(item: $playbackSelection) { selection in
                PlayerView(
                    item: selection.item,
                    store: store,
                    offlineDownload: selection.offlineDownload
                )
                .environment(theme)
                .frame(minWidth: 820, minHeight: 520)
            }
        #endif
        #if os(iOS)
            .fullScreenCover(item: $downloadItem) { selected in
                DownloadOptionsView(item: selected, store: store)
                .environment(theme)
            }
        #else
            .sheet(item: $downloadItem) { selected in
                DownloadOptionsView(item: selected, store: store)
                .environment(theme)
                .frame(minWidth: 520, minHeight: 620)
            }
        #endif
        .overlay {
            if showsClearConfirmation {
                PixelConfirmationDialog(
                    title: "CLEAR THIS DOWNLOAD?",
                    message: "REMOVE THE DOWNLOAD FROM THIS DEVICE. THE SERVER COPY STAYS SAFE.",
                    actionTitle: "CLEAR",
                    onConfirm: {
                        if let localRecord { store.downloads.remove(localRecord) }
                    },
                    onDismiss: { showsClearConfirmation = false }
                )
            }
        }
    }

    #if os(iOS)
        private var detailHeader: some View {
            HStack(spacing: 10) {
                Button("BACK") { dismiss() }
                    .buttonStyle(PixelCompactButtonStyle())
                    .accessibilityIdentifier("detail.back")
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name.uppercased())
                        .font(.pixel(.callout))
                        .lineLimit(1)
                    Text(item.mediaKind)
                        .font(.pixel(.caption2))
                        .foregroundStyle(theme.secondaryInk)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(theme.ink)
            .pixelPanel(padding: 10)
        }
    #endif

    private var poster: some View {
        PosterImage(
            item: item,
            request: isPresentingOffline ? nil : store.imageRequest(for: item, maxWidth: 700),
            localURL: isPresentingOffline ? localRecord.flatMap(store.downloads.posterURL) : nil
        )
        .aspectRatio(2 / 3, contentMode: .fit)
        .overlay { PixelFrame() }
    }

    private var facts: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.name.uppercased())
                    .font(.pixel(.title))
                    .foregroundStyle(theme.ink)

                Text(metadataLine)
                    .font(.pixel(.caption))
                    .foregroundStyle(theme.secondaryInk)
            }

            if !item.isSeries {
                Button {
                    play(isPresentingOffline ? localRecord : nil)
                } label: {
                    HStack {
                        PixelCursor(isVisible: true)
                        Text(playButtonTitle)
                    }
                }
                .buttonStyle(PixelButtonStyle())

                downloadActions
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("ABOUT")
                    .font(.pixel(.caption))
                Text((item.overview?.isEmpty == false ? item.overview : nil) ?? "NO DESCRIPTION AVAILABLE.")
                    .font(.pixel(.callout))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(theme.ink)
            .pixelPanel()
        }
    }

    private var metadataLine: String {
        var parts = [item.mediaKind]
        if let year = item.productionYear { parts.append(String(year)) }
        if let duration = item.durationText { parts.append(duration) }
        if let rating = item.communityRating { parts.append(String(format: "R %.1f", rating)) }
        return parts.joined(separator: " // ")
    }

    private var playButtonTitle: String {
        if isPresentingOffline { return "PLAY OFFLINE" }
        if item.resumeTicks > 0 { return "RESUME" }
        if item.isAudio { return "LISTEN" }
        if item.isLiveChannel { return "WATCH LIVE" }
        return "WATCH"
    }

    @ViewBuilder
    private var downloadActions: some View {
        if !store.isDemo, !item.isLiveChannel {
            if let phase = store.downloads.phase(for: item.id) {
                switch phase {
                case .preparing, .downloading:
                    Text(phase.title)
                        .font(.pixel(.caption2))
                        .foregroundStyle(theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .pixelPanel(padding: 10)
                    Button("CANCEL DOWNLOAD") {
                        store.downloads.cancel(itemID: item.id)
                    }
                    .buttonStyle(PixelOutlineButtonStyle())

                case .failed(let message):
                    Text(message)
                        .font(.pixel(.caption2))
                        .foregroundStyle(theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .pixelPanel(padding: 10)
                    Button(phase.title) { downloadItem = item }
                        .buttonStyle(PixelOutlineButtonStyle())
                }
            } else if let localRecord {
                if !isPresentingOffline {
                    Button("PLAY OFFLINE") { play(localRecord) }
                        .buttonStyle(PixelOutlineButtonStyle())
                }

                Text(offlineSummary(for: localRecord))
                    .font(.pixel(.caption2))
                    .foregroundStyle(theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .pixelPanel(padding: 10)

                Button("CLEAR DOWNLOAD") { showsClearConfirmation = true }
                    .buttonStyle(PixelOutlineButtonStyle())
            } else {
                Button("DOWNLOAD...") { downloadItem = item }
                    .buttonStyle(PixelOutlineButtonStyle())
                    .accessibilityIdentifier("detail.download")
            }
        }
    }

    private var localRecord: OfflineDownload? {
        let current = store.downloads.record(for: item.id)
        guard let offlineDownload else { return current }
        return current?.id == offlineDownload.id ? offlineDownload : current
    }

    private var isPresentingOffline: Bool {
        guard let offlineDownload else { return false }
        return localRecord?.id == offlineDownload.id
    }

    private func play(_ offlineDownload: OfflineDownload?) {
        playbackSelection = PlaybackSelection(item: item, offlineDownload: offlineDownload)
    }

    private func offlineSummary(for download: OfflineDownload) -> String {
        "QUALITY \(download.quality.title) // AUDIO \(download.audioTitle) // "
            + "SUBTITLES \(download.subtitleTitle) // \(download.sizeText)"
    }

}

private struct PlaybackSelection: Identifiable {
    let id = UUID()
    let item: MediaItem
    var offlineDownload: OfflineDownload? = nil
}
