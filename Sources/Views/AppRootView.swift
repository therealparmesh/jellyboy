import SwiftUI

struct AppRootView: View {
    let store: AppStore
    @Environment(GameBoyTheme.self) private var theme
    @Environment(\.colorScheme) private var systemColorScheme

    var body: some View {
        ZStack {
            if ProcessInfo.processInfo.arguments.contains("--demo-player"),
                let sample = MediaItem.sampleLibrary.first
            {
                PlayerView(item: sample, store: store)
            } else if store.isConnected {
                LibraryView(store: store)
            } else {
                ConnectView(store: store)
            }

        }
        .lineSpacing(4)
        .preferredColorScheme(theme.appearanceMode.preferredColorScheme)
        .onAppear {
            theme.systemColorScheme = systemColorScheme
        }
        .onChange(of: systemColorScheme) { _, newValue in
            theme.systemColorScheme = newValue
        }
    }
}

#Preview("Library — Light") {
    AppRootView(store: .previewLibrary())
        .environment(GameBoyTheme(appearanceMode: .light, persistsChanges: false))
        .frame(minWidth: 390, minHeight: 720)
}

#Preview("Connect — Dark") {
    AppRootView(store: .previewSignedOut())
        .environment(GameBoyTheme(appearanceMode: .dark, persistsChanges: false))
        .frame(minWidth: 390, minHeight: 720)
}
