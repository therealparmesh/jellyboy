import SwiftUI

struct SettingsView: View {
    let store: AppStore

    @Environment(GameBoyTheme.self) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var showsChangeServerConfirmation = false

    var body: some View {
        ZStack {
            theme.screen.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("SETTINGS")
                                .font(.pixel(.title))
                            Text("APP PREFERENCES")
                                .font(.pixel(.caption2))
                                .foregroundStyle(theme.secondaryInk)
                        }
                        Spacer()
                        Button("DONE") { dismiss() }
                            .buttonStyle(PixelCompactButtonStyle())
                            .accessibilityLabel("Close settings")
                    }
                    .foregroundStyle(theme.ink)
                    .pixelPanel(padding: 10)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("APPEARANCE")
                            .font(.pixel(.caption))
                        AppearancePicker()
                        Text("COLOR PALETTE")
                            .font(.pixel(.caption))
                        VersionPicker()
                        Text(appearanceDescription)
                            .font(.pixel(.caption2))
                            .foregroundStyle(theme.secondaryInk)
                    }
                    .foregroundStyle(theme.ink)
                    .pixelPanel()

                    VStack(alignment: .leading, spacing: 14) {
                        Text("CONNECTION")
                            .font(.pixel(.caption))
                        settingRow("SIGNED IN AS", store.session?.username.uppercased() ?? "NONE")
                        settingRow("SERVER", displayServer)
                        settingRow("LIBRARY", store.isDemo ? "SAMPLE LIBRARY" : "JELLYFIN")
                    }
                    .foregroundStyle(theme.ink)
                    .pixelPanel()

                    Text("YOUR SIGN-IN TOKEN IS KEPT IN KEYCHAIN. USE HTTPS OUTSIDE YOUR HOME NETWORK.")
                        .font(.pixel(.caption2))
                        .lineSpacing(4)
                        .foregroundStyle(theme.secondaryInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .pixelPanel()

                    VStack(alignment: .leading, spacing: 14) {
                        Text("HELP")
                            .font(.pixel(.caption))
                        HStack(spacing: 10) {
                            Link("SUPPORT", destination: Self.supportURL)
                                .buttonStyle(PixelOutlineButtonStyle())
                            Link("PRIVACY", destination: Self.privacyURL)
                                .buttonStyle(PixelOutlineButtonStyle())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(theme.ink)
                    .pixelPanel()

                    Button(store.isDemo ? "EXIT SAMPLE LIBRARY" : "CHANGE SERVER") {
                        showsChangeServerConfirmation = true
                    }
                    .buttonStyle(PixelButtonStyle())
                }
                .padding(24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
        #endif
        .preferredColorScheme(theme.appearanceMode.preferredColorScheme)
        .frame(minWidth: 360, idealWidth: 520, minHeight: 460, idealHeight: 620)
        .overlay {
            if showsChangeServerConfirmation {
                PixelConfirmationDialog(
                    title: store.isDemo ? "EXIT SAMPLE LIBRARY?" : "CHANGE SERVER?",
                    message: store.isDemo
                        ? "RETURN TO THE CONNECTION SCREEN."
                        : changeServerMessage,
                    actionTitle: store.isDemo ? "EXIT" : "CHANGE",
                    onConfirm: {
                        store.signOut()
                        dismiss()
                    },
                    onDismiss: { showsChangeServerConfirmation = false }
                )
            }
        }
    }

    private var displayServer: String {
        guard let value = store.session?.serverURL, !store.isDemo else { return "LOCAL DEMO" }
        return
            value
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .uppercased()
    }

    private static let supportURL = URL(
        string: "https://therealparmesh.github.io/jellyboy/support"
    )!
    private static let privacyURL = URL(
        string: "https://therealparmesh.github.io/jellyboy/privacy"
    )!

    private var changeServerMessage: String {
        "RETURN TO CONNECTION? THIS URL STAYS IN RECENTS. "
            + "THE SAVED LOGIN IS REMOVED, AND DOWNLOADS STAY ON THIS DEVICE."
    }

    private var appearanceDescription: String {
        let version = theme.gameVersion.title
        return switch theme.appearanceMode {
        case .system: "SYSTEM USES THE \(version) PALETTE AND MATCHES THIS DEVICE."
        case .light: "LIGHT USES THE ORIGINAL \(version) GBC COMPATIBILITY PALETTE."
        case .dark: "DARK REARRANGES THE SAME \(version) COLORS FOR LOW LIGHT."
        }
    }

    private func settingRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.pixel(.caption2))
                .foregroundStyle(theme.secondaryInk)
            Spacer()
            Text(value)
                .font(.pixel(.caption))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
