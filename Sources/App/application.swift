import SwiftUI

@main
struct MediaApplication: App {
    @State private var store = AppStore()
    @State private var theme = GameBoyTheme()

    init() {
        PixelFontRegistration.register()
    }

    var body: some Scene {
        WindowGroup("jellyboy", id: "library") {
            AppRootView(store: store)
                .environment(theme)
        }
        #if os(macOS)
            .defaultSize(width: 1_040, height: 720)
        #endif
        .commands {
            CommandMenu("Library") {
                Button("Reload Libraries") {
                    Task { await store.loadLibraries(force: true) }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(!store.isConnected)

                Button("Change Server…") {
                    store.signOut()
                }
                .disabled(!store.isConnected)
            }
        }

        #if os(macOS)
            Settings {
                SettingsView(store: store)
                    .environment(theme)
            }
        #endif
    }
}
