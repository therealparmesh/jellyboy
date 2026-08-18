import SwiftUI

struct ConnectView: View {
    private enum Field: Hashable {
        case server
        case username
        case password
    }

    let store: AppStore

    @Environment(GameBoyTheme.self) private var theme
    @State private var server = ""
    @State private var username = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    var body: some View {
        ZStack {
            theme.screen.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 12) {
                        JellySprite()
                            .frame(width: 112, height: 112)

                        Text("jellyboy")
                            .font(.pixel(.largeTitle))
                            .foregroundStyle(theme.ink)

                        Text("TINY JELLYFIN PLAYER")
                            .font(.pixel(.caption))
                            .foregroundStyle(theme.secondaryInk)
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        fieldLabel("SERVER")
                        serverField

                        fieldLabel("USERNAME")
                        TextField(
                            "",
                            text: $username,
                            prompt: Text("JELLYFIN USERNAME").foregroundStyle(theme.mid)
                        )
                        .focused($focusedField, equals: .username)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                        .pixelField()

                        fieldLabel("PASSWORD")
                        SecureField(
                            "",
                            text: $password,
                            prompt: Text("OPTIONAL").foregroundStyle(theme.mid)
                        )
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit(connect)
                        .pixelField()

                        if let error = store.connectionError {
                            HStack(alignment: .top, spacing: 8) {
                                PixelCursor(isVisible: true)
                                Text(error)
                                    .font(.pixel(.caption))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .foregroundStyle(theme.ink)
                            .accessibilityLabel(error)
                        }

                        Button(action: connect) {
                            if store.isConnecting {
                                Text("...")
                                    .accessibilityLabel("Connecting")
                            } else {
                                Text("CONNECT")
                            }
                        }
                        .buttonStyle(PixelButtonStyle())
                        .disabled(
                            server.trimmingCharacters(in: .whitespaces).isEmpty
                                || username.trimmingCharacters(in: .whitespaces).isEmpty || store.isConnecting)
                    }
                    .pixelPanel()

                    if !store.recentServerURLs.isEmpty {
                        recentServersPanel
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("APPEARANCE")
                            .font(.pixel(.caption))
                            .foregroundStyle(theme.ink)
                        AppearancePicker()
                        Text("COLOR PALETTE")
                            .font(.pixel(.caption))
                            .foregroundStyle(theme.ink)
                        VersionPicker()
                    }
                    .pixelPanel()

                    Button("OPEN SAMPLE LIBRARY") {
                        store.openDemo()
                    }
                    .buttonStyle(PixelOutlineButtonStyle())

                    Text("USE HTTPS OUTSIDE YOUR HOME NETWORK. LOCAL HTTP ALSO WORKS.")
                        .font(.pixel(.caption2))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(theme.secondaryInk)
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, 20)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            if server.isEmpty {
                server = store.recentServerURLs.first ?? ""
            }
        }
    }

    private var recentServersPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("RECENT SERVERS")
                    .font(.pixel(.caption))
                Spacer()
                Button("CLEAR") {
                    store.clearRecentServers()
                }
                .buttonStyle(PixelCompactButtonStyle())
                .accessibilityLabel("Clear recent servers")
            }

            ForEach(store.recentServerURLs, id: \.self) { recentServer in
                Button {
                    server = recentServer
                    focusedField = .username
                } label: {
                    HStack(spacing: 9) {
                        PixelCursor(isVisible: server == recentServer)
                        Text(recentServer)
                            .font(.pixel(.caption))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(theme.ink)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .background(server == recentServer ? theme.selection : theme.paper)
                    .overlay { PixelFrame() }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Use recent server \(recentServer)")
                .accessibilityAddTraits(server == recentServer ? .isSelected : [])
            }
        }
        .foregroundStyle(theme.ink)
        .pixelPanel()
    }

    private var serverField: some View {
        TextField(
            "",
            text: $server,
            prompt: Text("192.168.1.2:8096").foregroundStyle(theme.mid)
        )
        .focused($focusedField, equals: .server)
        #if os(iOS)
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
        #endif
        .autocorrectionDisabled()
        .submitLabel(.next)
        .onSubmit { focusedField = .username }
        .pixelField()
    }

    private func fieldLabel(_ value: String) -> some View {
        Text(value)
            .font(.pixel(.caption))
            .foregroundStyle(theme.ink)
    }

    private func connect() {
        Task {
            await store.connect(server: server, username: username, password: password)
        }
    }
}
