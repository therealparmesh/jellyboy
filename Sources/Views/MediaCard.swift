import SwiftUI

struct MediaCard: View {
    let item: MediaItem
    let store: AppStore
    var offlineDownload: OfflineDownload? = nil
    let width: CGFloat

    @Environment(GameBoyTheme.self) private var theme
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PosterImage(
                item: item,
                request: offlineDownload == nil ? store.imageRequest(for: item) : nil,
                localURL: offlineDownload.flatMap(store.downloads.posterURL)
            )
            .frame(width: width, height: width * 1.5)
            .overlay(alignment: .topTrailing) {
                Text(badgeTitle)
                    .font(.pixel(.caption2))
                    .foregroundStyle(theme.paper)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(theme.ink)
                    .padding(6)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(item.name.uppercased())
                    .font(.pixel(.caption))
                    .lineLimit(2, reservesSpace: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(theme.ink)

                HStack {
                    if item.isLiveChannel {
                        Text("LIVE NOW")
                    } else {
                        Text(item.productionYear.map(String.init) ?? "----")
                    }
                    Spacer()
                    if !item.isLiveChannel, let rating = item.communityRating {
                        Text(String(format: "R %.1f", rating))
                    }
                }
                .font(.pixel(.caption2))
                .foregroundStyle(theme.secondaryInk)

                if item.progress > 0 {
                    PixelProgressBar(value: item.progress)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovering ? theme.selection : theme.panel)
        }
        .frame(width: width)
        .overlay { PixelFrame() }
        .clipped()
        .contentShape(Rectangle())
        #if os(macOS)
            .onHover { isHovering = $0 }
        #endif
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Opens details")
    }

    private var badgeTitle: String {
        if offlineDownload != nil { return "OFFLINE" }
        return switch store.downloads.phase(for: item.id) {
        case .preparing: "PREPARING"
        case .downloading: "SAVING"
        case .failed: "FAILED"
        case nil: item.mediaKind
        }
    }

    private var accessibilityText: String {
        var parts = [item.name, offlineDownload == nil ? item.mediaKind : "DOWNLOADED"]
        if let year = item.productionYear { parts.append(String(year)) }
        if let rating = item.communityRating { parts.append(String(format: "RATING %.1f", rating)) }
        if item.progress > 0 { parts.append("\(Int(item.progress * 100)) PERCENT PLAYED") }
        if let phase = store.downloads.phase(for: item.id) { parts.append(phase.accessibilityTitle) }
        return parts.joined(separator: ", ")
    }
}
