import SwiftUI

struct EpisodeListView: View {
    private enum EpisodeLoadState {
        case idle
        case loading
        case loaded([MediaItem])
        case failed(String)
    }

    let series: MediaItem
    let store: AppStore
    let onPlay: (MediaItem) -> Void
    let onDownload: (MediaItem) -> Void

    @Environment(GameBoyTheme.self) private var theme
    @State private var state: EpisodeLoadState = .idle

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("EPISODES")
                .font(.pixel(.headline))
                .foregroundStyle(theme.ink)

            content
        }
        .task(id: series.id) { await loadEpisodes() }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle, .loading:
            HStack(spacing: 10) {
                Text("...")
                Text("LOADING EPISODES...")
            }
            .font(.pixel(.caption))
            .foregroundStyle(theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pixelPanel()

        case .failed(let message):
            VStack(spacing: 12) {
                Text(message)
                Button("TRY AGAIN") {
                    Task { await loadEpisodes() }
                }
                .buttonStyle(PixelButtonStyle(fillsWidth: false))
            }
            .font(.pixel(.caption))
            .foregroundStyle(theme.ink)
            .frame(maxWidth: .infinity)
            .pixelPanel()

        case .loaded(let episodes):
            if episodes.isEmpty {
                Text("NO EPISODES FOUND.")
                    .font(.pixel(.caption))
                    .foregroundStyle(theme.ink)
                    .frame(maxWidth: .infinity)
                    .pixelPanel()
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(episodes) { episode in
                        HStack(spacing: 8) {
                            Button {
                                onPlay(episode)
                            } label: {
                                EpisodeRow(episode: episode)
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if !store.isDemo {
                                Button("SAVE") { onDownload(episode) }
                                    .buttonStyle(PixelOutlineButtonStyle(fillsWidth: false))
                                    .accessibilityLabel("Download \(episode.name)")
                            }
                        }
                    }
                }
            }
        }
    }

    private func loadEpisodes() async {
        state = .loading
        do {
            let episodes = try await store.episodes(for: series)
            guard !Task.isCancelled else { return }
            state = .loaded(episodes)
        } catch is CancellationError {
            return
        } catch {
            state = .failed(
                (error as? LocalizedError)?.errorDescription ?? "EPISODES COULDN'T LOAD."
            )
        }
    }
}

private struct EpisodeRow: View {
    @Environment(GameBoyTheme.self) private var theme
    let episode: MediaItem

    var body: some View {
        HStack(spacing: 8) {
            PixelCursor(isVisible: true)
            VStack(alignment: .leading, spacing: 7) {
                Text([episode.episodeCode, episode.name.uppercased()].compactMap { $0 }.joined(separator: " // "))
                    .font(.pixel(.callout))
                    .lineLimit(2)
                if let duration = episode.durationText {
                    Text(duration)
                        .font(.pixel(.caption2))
                        .foregroundStyle(theme.secondaryInk)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(episode.resumeTicks > 0 ? "RESUME" : "PLAY")
                .font(.pixel(.caption2))
                .foregroundStyle(theme.paper)
                .padding(.horizontal, 8)
                .frame(minHeight: 34)
                .background(theme.accent)
                .overlay { PixelFrame() }
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(theme.ink)
        .pixelPanel(padding: 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts = [episode.episodeCode, episode.name, episode.resumeTicks > 0 ? "RESUME" : "PLAY"]
            .compactMap { $0 }
        if let ticks = episode.runTimeTicks {
            let minutes = max(Int(Double(ticks) / 10_000_000 / 60), 1)
            parts.insert("\(minutes) MINUTES", at: max(parts.count - 1, 0))
        }
        return parts.joined(separator: ", ")
    }
}
