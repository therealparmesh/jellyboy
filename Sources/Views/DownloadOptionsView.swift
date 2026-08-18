import SwiftUI

struct DownloadOptionsView: View {
    private enum ChoiceState {
        case loading
        case loaded(PlaybackMediaSource)
        case failed(String)
    }

    private enum ActiveChoice: String {
        case quality = "QUALITY"
        case audio = "AUDIO"
        case subtitles = "SUBTITLES"
    }

    let item: MediaItem
    let store: AppStore

    @Environment(\.dismiss) private var dismiss
    @Environment(GameBoyTheme.self) private var theme
    @State private var state: ChoiceState = .loading
    @State private var quality: PlaybackQuality = .maximum
    @State private var audioStreamIndex: Int?
    @State private var subtitleStreamIndex: Int?
    @State private var activeChoice: ActiveChoice?

    var body: some View {
        ZStack {
            theme.screen.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    content
                }
                .padding(18)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
        #endif
        .task(id: item.id) { await loadChoices() }
        .overlay {
            if let activeChoice, case .loaded(let source) = state {
                PixelChoiceMenu(
                    title: activeChoice.rawValue,
                    options: menuOptions(for: activeChoice, source: source),
                    onSelect: { select($0, in: activeChoice) },
                    onDismiss: { self.activeChoice = nil }
                )
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.name.uppercased())
                    .font(.pixel(.headline))
                Text("DOWNLOAD FOR OFFLINE PLAY")
                    .font(.pixel(.caption2))
                    .foregroundStyle(theme.secondaryInk)
            }
            Spacer(minLength: 4)
            Button("×") { dismiss() }
                .buttonStyle(PixelCompactButtonStyle())
                .accessibilityLabel("Close download options")
        }
        .foregroundStyle(theme.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel()
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            PixelDownloadState(title: "LOADING DOWNLOAD OPTIONS...", showsProgress: true)

        case .failed(let message):
            PixelDownloadState(title: message, actionTitle: "TRY AGAIN") {
                Task { await loadChoices() }
            }

        case .loaded(let source):
            VStack(spacing: 16) {
                optionButton("QUALITY", value: quality.title, choice: .quality)

                optionButton(
                    "AUDIO",
                    value: source.audioStreams.first { $0.index == audioStreamIndex }?.selectorTitle ?? "AUTO",
                    accessibilityValue: source.audioStreams.first { $0.index == audioStreamIndex }?.menuTitle ?? "AUTO",
                    choice: .audio
                )

                if !item.isAudio {
                    optionButton(
                        "SUBTITLES",
                        value: source.subtitleStreams.first { $0.index == subtitleStreamIndex }?.selectorTitle ?? "OFF",
                        accessibilityValue: source.subtitleStreams.first { $0.index == subtitleStreamIndex }?.menuTitle
                            ?? "OFF",
                        choice: .subtitles
                    )
                }

                Text(policyMessage(source: source))
                    .font(.pixel(.caption2))
                    .foregroundStyle(theme.ink)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .pixelPanel(padding: 12)

                Button(startButtonTitle) {
                    store.downloads.start(
                        item: item,
                        options: OfflineDownloadOptions(
                            quality: quality,
                            audioStreamIndex: audioStreamIndex,
                            subtitleStreamIndex: subtitleStreamIndex
                        ),
                        store: store
                    )
                    dismiss()
                }
                .buttonStyle(PixelButtonStyle())
                .accessibilityIdentifier("download.start")

                Button("CANCEL") { dismiss() }
                    .buttonStyle(PixelOutlineButtonStyle())
            }
        }
    }

    private func optionButton(
        _ title: String,
        value: String,
        accessibilityValue: String? = nil,
        choice: ActiveChoice
    ) -> some View {
        Button {
            activeChoice = choice
        } label: {
            PixelSelectorLabel(title: title, value: value)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue ?? value)
    }

    private var startButtonTitle: String {
        store.downloads.record(for: item.id) == nil ? "START DOWNLOAD" : "REPLACE DOWNLOAD"
    }

    private func policyMessage(source: PlaybackMediaSource) -> String {
        if let selected = source.subtitleStreams.first(where: { $0.index == subtitleStreamIndex }),
            selected.requiresBurnInForOffline
        {
            return "IMAGE SUBTITLES MUST BE BURNED INTO THE VIDEO. THIS USES SERVER TRANSCODING."
        }
        if quality != .maximum {
            return "THE SERVER TRANSCODES ONLY IF THE SOURCE IS ABOVE THIS QUALITY LIMIT."
        }
        return "MAXIMUM AVOIDS QUALITY-BASED TRANSCODING. SELECTED TEXT SUBTITLES ARE SAVED SEPARATELY."
    }

    private func loadChoices() async {
        state = .loading
        do {
            let source = try await store.offlineChoices(for: item)
            guard !Task.isCancelled else { return }
            audioStreamIndex =
                source.audioStreams.first(where: \.isDefault)?.index
                ?? source.audioStreams.first?.index
            subtitleStreamIndex = nil
            state = .loaded(source)
        } catch is CancellationError {
            return
        } catch {
            state = .failed(
                (error as? LocalizedError)?.errorDescription ?? "DOWNLOAD OPTIONS COULDN'T LOAD."
            )
        }
    }

    private func menuOptions(
        for choice: ActiveChoice,
        source: PlaybackMediaSource
    ) -> [PixelMenuOption] {
        switch choice {
        case .quality:
            return PlaybackQuality.options(for: source, audioOnly: item.isAudio).map {
                PixelMenuOption(
                    id: String($0.rawValue),
                    title: $0.title,
                    isSelected: quality == $0
                )
            }
        case .audio:
            guard !source.audioStreams.isEmpty else {
                return [PixelMenuOption(id: "auto", title: "AUTO", isSelected: true, isEnabled: false)]
            }
            return source.audioStreams.map {
                PixelMenuOption(
                    id: String($0.index),
                    title: $0.menuTitle,
                    isSelected: audioStreamIndex == $0.index
                )
            }
        case .subtitles:
            return [PixelMenuOption(id: "off", title: "OFF", isSelected: subtitleStreamIndex == nil)]
                + source.subtitleStreams.map {
                    PixelMenuOption(
                        id: String($0.index),
                        title: $0.menuTitle,
                        isSelected: subtitleStreamIndex == $0.index
                    )
                }
        }
    }

    private func select(_ id: String, in choice: ActiveChoice) {
        switch choice {
        case .quality:
            if let rawValue = Int(id), let nextQuality = PlaybackQuality(rawValue: rawValue) {
                quality = nextQuality
            }
        case .audio:
            audioStreamIndex = Int(id)
        case .subtitles:
            subtitleStreamIndex = Int(id)
        }
        activeChoice = nil
    }
}

private struct PixelDownloadState: View {
    @Environment(GameBoyTheme.self) private var theme
    let title: String
    var showsProgress = false
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            if showsProgress {
                Text("...")
                    .accessibilityLabel("Loading")
            }
            Text(title)
                .font(.pixel(.callout))
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(PixelButtonStyle(fillsWidth: false))
            }
        }
        .foregroundStyle(theme.ink)
        .frame(maxWidth: .infinity)
        .pixelPanel()
    }
}
