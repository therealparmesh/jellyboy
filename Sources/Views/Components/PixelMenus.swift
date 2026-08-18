import SwiftUI

struct PixelMenuOption: Identifiable, Equatable {
    let id: String
    let title: String
    var isSelected = false
    var isEnabled = true
}

struct PixelSelectorLabel: View {
    @Environment(GameBoyTheme.self) private var theme

    let title: String
    let value: String
    var showsDisclosure = true

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.pixel(.caption2))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Text(value)
                    .font(.pixel(.caption2))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            Spacer(minLength: 4)
            if showsDisclosure {
                Text("▼")
                    .font(.pixel(.caption2))
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(theme.ink)
        .padding(.horizontal, 7)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .background(theme.panel)
        .overlay { PixelFrame() }
        .contentShape(Rectangle())
    }
}

struct PixelChoiceMenu: View {
    @Environment(GameBoyTheme.self) private var theme

    let title: String
    let options: [PixelMenuOption]
    let onSelect: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Button(action: onDismiss) {
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close \(title) menu")

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title.uppercased())
                        .font(.pixel(.headline))
                    Spacer()
                    Button("BACK", action: onDismiss)
                        .buttonStyle(PixelCompactButtonStyle())
                        .accessibilityLabel("Close menu")
                }

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(options) { option in
                            Button {
                                onSelect(option.id)
                            } label: {
                                HStack(spacing: 9) {
                                    PixelCursor(isVisible: option.isSelected)
                                    Text(option.title.uppercased())
                                        .font(.pixel(.callout))
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                }
                                .foregroundStyle(theme.ink)
                                .padding(.horizontal, 8)
                                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                                .background(theme.paper)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(!option.isEnabled)
                            .opacity(option.isEnabled ? 1 : theme.disabledControlOpacity)
                            .accessibilityAddTraits(option.isSelected ? .isSelected : [])
                        }
                    }
                }
                .frame(height: min(CGFloat(max(options.count, 1)) * 52, 364))
            }
            .foregroundStyle(theme.ink)
            .frame(maxWidth: 360)
            .pixelPanel(padding: 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(16)
        }
        .zIndex(100)
        .accessibilityAddTraits(.isModal)
    }
}

struct PixelConfirmationDialog: View {
    @Environment(GameBoyTheme.self) private var theme

    let title: String
    let message: String
    let actionTitle: String
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 9) {
                    PixelCursor(isVisible: true)
                    VStack(alignment: .leading, spacing: 7) {
                        Text(title.uppercased())
                            .font(.pixel(.headline))
                        Text(message.uppercased())
                            .font(.pixel(.caption))
                            .lineSpacing(3)
                    }
                }

                HStack(spacing: 9) {
                    Button("CANCEL", action: onDismiss)
                        .buttonStyle(PixelOutlineButtonStyle())
                    Button(actionTitle.uppercased()) {
                        onConfirm()
                        onDismiss()
                    }
                    .buttonStyle(PixelButtonStyle())
                }
            }
            .foregroundStyle(theme.ink)
            .frame(maxWidth: 420)
            .pixelPanel()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(16)
        }
        .zIndex(100)
        .accessibilityAddTraits(.isModal)
    }
}

struct PixelSearchField: View {
    @Environment(GameBoyTheme.self) private var theme
    @Binding var text: String

    var body: some View {
        HStack(spacing: 9) {
            PixelCursor(isVisible: true)
            TextField(
                "",
                text: $text,
                prompt: Text("SEARCH THIS LIBRARY").foregroundStyle(theme.mid)
            )
            .textFieldStyle(.plain)
            .font(.pixel(.callout))
            .foregroundStyle(theme.ink)
            #if os(iOS)
                .textInputAutocapitalization(.never)
            #endif
            .autocorrectionDisabled()
            .accessibilityIdentifier("library.search")

            if !text.isEmpty {
                Button("×") { text = "" }
                    .buttonStyle(PixelCompactButtonStyle())
                    .accessibilityLabel("Clear search")
            }
        }
        .foregroundStyle(theme.ink)
        .pixelPanel(padding: 8)
    }
}
