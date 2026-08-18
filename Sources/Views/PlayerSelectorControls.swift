import SwiftUI

@MainActor
enum PlayerSelectorKind: String {
    case quality = "QUALITY"
    case audio = "AUDIO"
    case subtitles = "SUBTITLES"
    case speed = "SPEED"

    func options(for coordinator: PlaybackCoordinator) -> [PixelMenuOption] {
        switch self {
        case .quality:
            return PlaybackQuality.options(for: coordinator.plan?.source).map {
                PixelMenuOption(
                    id: String($0.rawValue),
                    title: $0.title,
                    isSelected: coordinator.quality == $0
                )
            }
        case .audio:
            guard !coordinator.audioStreams.isEmpty else {
                return [PixelMenuOption(id: "none", title: "NO AUDIO TRACKS", isEnabled: false)]
            }
            return coordinator.audioStreams.map {
                PixelMenuOption(
                    id: String($0.index),
                    title: $0.menuTitle,
                    isSelected: coordinator.selectedAudioIndex == $0.index
                )
            }
        case .subtitles:
            return [PixelMenuOption(id: "off", title: "OFF", isSelected: coordinator.selectedSubtitleIndex == nil)]
                + coordinator.subtitleStreams.map {
                    PixelMenuOption(
                        id: String($0.index),
                        title: $0.menuTitle,
                        isSelected: coordinator.selectedSubtitleIndex == $0.index
                    )
                }
        case .speed:
            return Self.speeds.map {
                PixelMenuOption(
                    id: String($0),
                    title: "\(Double($0).formatted())×",
                    isSelected: coordinator.speed == $0
                )
            }
        }
    }

    func select(_ id: String, coordinator: PlaybackCoordinator) {
        switch self {
        case .quality:
            guard let value = Int(id), let quality = PlaybackQuality(rawValue: value) else { return }
            coordinator.selectQuality(quality)
        case .audio:
            guard let value = Int(id),
                let stream = coordinator.audioStreams.first(where: { $0.index == value })
            else { return }
            coordinator.selectAudio(stream)
        case .subtitles:
            let stream = Int(id).flatMap { value in
                coordinator.subtitleStreams.first { $0.index == value }
            }
            coordinator.selectSubtitle(stream)
        case .speed:
            guard let value = Float(id) else { return }
            coordinator.setSpeed(value)
        }
    }

    private static let speeds: [Float] = [0.5, 0.75, 1, 1.25, 1.5, 2]
}

struct PlayerSelectorControls: View {
    @Environment(GameBoyTheme.self) private var theme
    let coordinator: PlaybackCoordinator
    let onOpen: (PlayerSelectorKind) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                selector(.quality)
                selector(.audio)
                selector(.subtitles)
                selector(.speed)
            }

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    selector(.quality)
                    selector(.speed)
                }
                HStack(spacing: 10) {
                    selector(.audio)
                    selector(.subtitles)
                }
            }
        }
    }

    private func selector(_ kind: PlayerSelectorKind) -> some View {
        Button {
            onOpen(kind)
        } label: {
            PixelSelectorLabel(
                title: kind.rawValue,
                value: value(for: kind),
                showsDisclosure: !isDisabled(kind)
            )
        }
        .buttonStyle(.plain)
        .frame(minWidth: 92)
        .disabled(isDisabled(kind))
        .opacity(isDisabled(kind) ? theme.disabledControlOpacity : 1)
        .accessibilityLabel(kind.rawValue.capitalized)
        .accessibilityValue(accessibilityValue(for: kind))
        .accessibilityIdentifier("player.\(kind.rawValue.lowercased())")
    }

    private func value(for kind: PlayerSelectorKind) -> String {
        switch kind {
        case .quality: coordinator.qualityTitle
        case .audio: coordinator.selectedAudio?.selectorTitle ?? "AUTO"
        case .subtitles: coordinator.selectedSubtitle?.selectorTitle ?? "OFF"
        case .speed: "\(Double(coordinator.speed).formatted())×"
        }
    }

    private func isDisabled(_ kind: PlayerSelectorKind) -> Bool {
        switch kind {
        case .quality, .subtitles:
            coordinator.isOffline
        case .audio:
            coordinator.isOffline || coordinator.audioStreams.isEmpty
        case .speed:
            false
        }
    }

    private func accessibilityValue(for kind: PlayerSelectorKind) -> String {
        switch kind {
        case .audio: coordinator.selectedAudio?.menuTitle ?? "AUTO"
        case .subtitles: coordinator.selectedSubtitle?.menuTitle ?? "OFF"
        case .quality, .speed: value(for: kind)
        }
    }
}
