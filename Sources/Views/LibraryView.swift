import SwiftUI

struct MediaGridMetrics: Equatable {
    static let minimumItemWidth: CGFloat = 132
    static let maximumItemWidth: CGFloat = 196
    static let spacing: CGFloat = 14

    let columnCount: Int
    let itemWidth: CGFloat

    init(availableWidth: CGFloat) {
        let availableWidth = max(availableWidth, Self.minimumItemWidth)
        columnCount = max(
            Int((availableWidth + Self.spacing) / (Self.minimumItemWidth + Self.spacing)),
            1
        )
        itemWidth = min(
            (availableWidth - Self.spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount),
            Self.maximumItemWidth
        )
    }
}

struct LibraryView: View {
    private static let libraryPrefix = "library:"
    private static let liveTVShelfID = "utility:live-tv"
    private static let offlineShelfID = "utility:offline"

    let store: AppStore

    @Environment(GameBoyTheme.self) private var theme
    @State private var query = ""
    @State private var showsSettings = false
    @State private var showsClearAllConfirmation = false
    @State private var showsShelfMenu = false
    @State private var selectedShelfID: String?
    @State private var viewportWidth: CGFloat = 0

    private let contentWidth: CGFloat = 1_100
    private var gridMetrics: MediaGridMetrics {
        MediaGridMetrics(availableWidth: min(max(viewportWidth - 32, 0), contentWidth))
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(
                .fixed(gridMetrics.itemWidth),
                spacing: MediaGridMetrics.spacing,
                alignment: .top
            ),
            count: gridMetrics.columnCount
        )
    }

    private var selectedLibrary: MediaLibrary? {
        guard let selectedShelfID, selectedShelfID.hasPrefix(Self.libraryPrefix) else { return nil }
        let libraryID = String(selectedShelfID.dropFirst(Self.libraryPrefix.count))
        return store.libraries.first { $0.id == libraryID }
    }

    private var shelfTitle: String {
        if let selectedLibrary { return selectedLibrary.name.uppercased() }
        switch selectedShelfID {
        case Self.liveTVShelfID: return "LIVE TV"
        case Self.offlineShelfID: return "OFFLINE"
        default: return "LIBRARIES"
        }
    }

    private var shelfOptions: [PixelMenuOption] {
        store.libraries.map { library in
            let id = Self.libraryPrefix + library.id
            return PixelMenuOption(
                id: id,
                title: library.name,
                isSelected: selectedShelfID == id
            )
        } + [
            PixelMenuOption(
                id: Self.liveTVShelfID,
                title: "LIVE TV",
                isSelected: selectedShelfID == Self.liveTVShelfID
            ),
            PixelMenuOption(
                id: Self.offlineShelfID,
                title: "OFFLINE",
                isSelected: selectedShelfID == Self.offlineShelfID
            ),
        ]
    }

    private var shelfItems: [MediaItem] {
        if let selectedLibrary { return store.items(in: selectedLibrary) }
        switch selectedShelfID {
        case Self.liveTVShelfID: return store.liveTVChannels
        case Self.offlineShelfID: return store.downloads.listedItems
        default: return []
        }
    }

    private var visibleItems: [MediaItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return shelfItems }
        return shelfItems.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    private var activeState: AppStore.LibraryState {
        if let selectedLibrary { return store.state(for: selectedLibrary) }
        switch selectedShelfID {
        case Self.liveTVShelfID: return store.liveTVState
        case Self.offlineShelfID: return .loaded
        default: return store.libraryState
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.screen.ignoresSafeArea()

                VStack(spacing: 0) {
                    libraryHeader
                        .frame(maxWidth: contentWidth)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 14)
                        .frame(maxWidth: .infinity)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            statusPanel
                            libraryContent
                        }
                        .frame(maxWidth: contentWidth)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 18)
                        .frame(maxWidth: .infinity)
                    }
                    .refreshable {
                        await reloadShelf(force: true)
                    }
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.width
                    } action: { width in
                        viewportWidth = width
                    }

                    PixelSearchField(text: $query)
                        .frame(maxWidth: contentWidth)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .frame(maxWidth: .infinity)
                }

                if showsShelfMenu {
                    PixelChoiceMenu(
                        title: "CHOOSE LIBRARY",
                        options: shelfOptions,
                        onSelect: { value in
                            selectedShelfID = value
                            query = ""
                            showsShelfMenu = false
                        },
                        onDismiss: { showsShelfMenu = false }
                    )
                }

                if showsClearAllConfirmation {
                    PixelConfirmationDialog(
                        title: "CLEAR ALL DOWNLOADS?",
                        message: "THIS REMOVES \(store.downloads.totalSizeText) FROM THIS DEVICE. "
                            + "THE SERVER COPIES STAY SAFE.",
                        actionTitle: "CLEAR ALL",
                        onConfirm: store.downloads.clearAll,
                        onDismiss: { showsClearAllConfirmation = false }
                    )
                }
            }
            #if os(iOS)
                .toolbar(.hidden, for: .navigationBar)
            #endif
            .task {
                await store.loadLibraries()
                selectDefaultShelf()
            }
            .task(id: selectedShelfID) {
                await reloadShelf(force: false)
            }
            .onChange(of: store.libraries) { _, _ in
                selectDefaultShelf()
            }
        }
        #if os(iOS)
            .fullScreenCover(isPresented: $showsSettings) {
                SettingsView(store: store)
                .environment(theme)
            }
        #endif
    }

    private var libraryHeader: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text("jellyboy")
                    .font(.pixel(.headline))
                Text("TINY JELLYFIN PLAYER")
                    .font(.pixel(.caption2))
                    .foregroundStyle(theme.secondaryInk)
            }

            Spacer(minLength: 4)

            if selectedShelfID == Self.offlineShelfID {
                Button("CLEAR") { showsClearAllConfirmation = true }
                    .buttonStyle(PixelCompactButtonStyle())
                    .disabled(store.downloads.records.isEmpty && store.downloads.phases.isEmpty)
                    .accessibilityLabel("Clear all downloads")
            } else {
                Button("REFRESH") {
                    Task { await reloadShelf(force: true) }
                }
                .buttonStyle(PixelCompactButtonStyle())
                .accessibilityLabel("Refresh current library")
            }

            #if os(macOS)
                SettingsLink {
                    Text("SETTINGS")
                }
                .buttonStyle(PixelCompactButtonStyle())
            #else
                Button("SETTINGS") { showsSettings = true }
                    .buttonStyle(PixelCompactButtonStyle())
                    .accessibilityLabel("Settings")
            #endif
        }
        .foregroundStyle(theme.ink)
        .pixelPanel(padding: 10)
    }

    private var statusPanel: some View {
        HStack(spacing: 12) {
            PixelCursor(isVisible: true)
            VStack(alignment: .leading, spacing: 6) {
                Text("\(shelfTitle) // \(itemCountText)")
                    .font(.pixel(.callout))
                    .lineLimit(2)
                Text(statusDetail)
                    .font(.pixel(.caption2))
                    .foregroundStyle(theme.secondaryInk)
            }
            Spacer(minLength: 8)
            Button {
                showsShelfMenu = true
            } label: {
                HStack(spacing: 6) {
                    Text(shelfTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("▼")
                        .accessibilityHidden(true)
                }
                .font(.pixel(.caption2))
                .foregroundStyle(theme.paper)
                .padding(.horizontal, 8)
                .frame(minHeight: 32)
                .background(theme.accent)
                .overlay { PixelFrame() }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Media library")
            .accessibilityValue(shelfTitle)
            .accessibilityIdentifier("library.shelf")
        }
        .foregroundStyle(theme.ink)
        .pixelPanel(padding: 12)
    }

    @ViewBuilder
    private var libraryContent: some View {
        switch activeState {
        case .idle where visibleItems.isEmpty,
            .loading where visibleItems.isEmpty:
            PixelStateView(
                title: selectedShelfID == nil ? "LOADING LIBRARIES..." : "LOADING \(shelfTitle)...",
                detail: "ASKING YOUR SERVER FOR TITLES.",
                showsProgress: true
            )

        case .failed(let message) where visibleItems.isEmpty:
            PixelStateView(title: "CONNECTION FAILED", detail: message, actionTitle: "TRY AGAIN") {
                Task { await reloadShelf(force: true) }
            }

        default:
            if visibleItems.isEmpty {
                PixelStateView(
                    title: query.isEmpty ? "EMPTY LIBRARY" : "NO MATCH",
                    detail: emptyLibraryMessage
                )
            } else {
                mediaGrid
            }
        }
    }

    @ViewBuilder
    private var mediaGrid: some View {
        if selectedShelfID == Self.offlineShelfID, visibleItems.count == 1, let item = visibleItems.first {
            HStack {
                Spacer(minLength: 0)
                mediaLink(for: item)
                    .frame(maxWidth: 196)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(visibleItems) { item in
                    mediaLink(for: item)
                        .frame(width: gridMetrics.itemWidth)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func mediaLink(for item: MediaItem) -> some View {
        let offlineDownload =
            selectedShelfID == Self.offlineShelfID
            ? store.downloads.record(for: item.id)
            : nil
        return NavigationLink {
            MediaDetailView(
                item: item,
                store: store,
                offlineDownload: offlineDownload
            )
        } label: {
            MediaCard(
                item: item,
                store: store,
                offlineDownload: offlineDownload,
                width: gridMetrics.itemWidth
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyLibraryMessage: String {
        guard query.isEmpty else { return "TRY ANOTHER SEARCH." }
        switch selectedShelfID {
        case Self.liveTVShelfID: return "NO LIVE TV CHANNELS WERE FOUND."
        case Self.offlineShelfID: return "DOWNLOAD A TITLE TO PLAY WITHOUT THE SERVER."
        case nil where store.libraryState == .loaded: return "THIS SERVER HAS NO MEDIA LIBRARIES."
        default: return "NO PLAYABLE TITLES WERE FOUND IN THIS LIBRARY."
        }
    }

    private var itemCountText: String {
        let noun: String
        switch selectedShelfID {
        case Self.liveTVShelfID: noun = visibleItems.count == 1 ? "CHANNEL" : "CHANNELS"
        case Self.offlineShelfID: noun = visibleItems.count == 1 ? "DOWNLOAD" : "DOWNLOADS"
        default: noun = visibleItems.count == 1 ? "ITEM" : "ITEMS"
        }
        return "\(visibleItems.count) \(noun)"
    }

    private func reloadShelf(force: Bool) async {
        if selectedShelfID == Self.liveTVShelfID {
            await store.loadLiveTV(force: force)
        } else if selectedShelfID != Self.offlineShelfID {
            if force { await store.loadLibraries(force: true) }
            guard let selectedLibrary else { return }
            await store.loadItems(in: selectedLibrary, force: force)
        }
    }

    private func selectDefaultShelf() {
        if selectedShelfID == Self.liveTVShelfID || selectedShelfID == Self.offlineShelfID {
            return
        }
        if selectedLibrary != nil { return }
        selectedShelfID = store.libraries.first.map { Self.libraryPrefix + $0.id }
    }

    private var statusDetail: String {
        if selectedShelfID == Self.offlineShelfID {
            return "\(store.downloads.totalSizeText) ON DEVICE"
        }
        return store.session?.username.uppercased() ?? "PLAYER"
    }
}
