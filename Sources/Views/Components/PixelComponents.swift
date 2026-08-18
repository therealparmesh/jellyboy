import SwiftUI

struct PixelPanelModifier: ViewModifier {
    @Environment(GameBoyTheme.self) private var theme
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(theme.panel)
            .overlay { PixelFrame() }
    }
}

extension View {
    func pixelPanel(padding: CGFloat = 16) -> some View {
        modifier(PixelPanelModifier(padding: padding))
    }

    func pixelField() -> some View {
        modifier(PixelFieldModifier())
    }
}

private struct PixelFieldModifier: ViewModifier {
    @Environment(GameBoyTheme.self) private var theme

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(.pixel(.body))
            .foregroundStyle(theme.ink)
            .padding(.horizontal, 12)
            .frame(minHeight: 50)
            .background(theme.paper)
            .overlay { PixelFrame() }
    }
}

struct PixelButtonStyle: ButtonStyle {
    @Environment(GameBoyTheme.self) private var theme
    @Environment(\.isEnabled) private var isEnabled
    var fillsWidth = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pixel(.body))
            .textCase(.uppercase)
            .foregroundStyle(theme.ink)
            .padding(.horizontal, 16)
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: 50)
            .background(
                isEnabled
                    ? (configuration.isPressed ? theme.pressedFill : theme.paper)
                    : theme.disabledFill
            )
            .overlay { PixelFrame() }
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : theme.disabledControlOpacity)
    }
}

struct PixelOutlineButtonStyle: ButtonStyle {
    @Environment(GameBoyTheme.self) private var theme
    var fillsWidth = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pixel(.caption))
            .foregroundStyle(theme.ink)
            .padding(.horizontal, 4)
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: 44)
            .background(configuration.isPressed ? theme.pressedFill : theme.paper)
            .overlay { PixelFrame() }
            .contentShape(Rectangle())
    }
}

struct PixelCompactButtonStyle: ButtonStyle {
    @Environment(GameBoyTheme.self) private var theme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pixel(.caption2))
            .foregroundStyle(theme.ink)
            .padding(.horizontal, 10)
            .frame(minHeight: 42)
            .background(
                !isEnabled
                    ? theme.disabledFill
                    : (configuration.isPressed ? theme.accentSoft : theme.paper)
            )
            .overlay { PixelFrame() }
            .contentShape(Rectangle())
    }
}

struct PixelFrame: View {
    @Environment(GameBoyTheme.self) private var theme

    private static let topLeft = [
        "........", ".#######", ".#......", ".#.#####", ".#.#....", ".#.#....", ".#.#....", ".#.#....",
    ]
    private static let top = [
        "........", "########", "........", "########", "........", "........", "........", "........",
    ]
    private static let topRight = [
        "........", "#######.", "......#.", "#####.#.", "....#.#.", "....#.#.", "....#.#.", "....#.#.",
    ]
    private static let left = [
        ".#.#....", ".#.#....", ".#.#....", ".#.#....", ".#.#....", ".#.#....", ".#.#....", ".#.#....",
    ]
    private static let right = [
        "....#.#.", "....#.#.", "....#.#.", "....#.#.", "....#.#.", "....#.#.", "....#.#.", "....#.#.",
    ]
    private static let bottom = [
        "........", "........", "........", "........", "########", "........", "########", "........",
    ]
    private static let bottomLeft = [
        ".#.#....", ".#.#....", ".#.#....", ".#.#....", ".#.#####", ".#......", ".#######", "........",
    ]
    private static let bottomRight = [
        "....#.#.", "....#.#.", "....#.#.", "....#.#.", "#####.#.", "......#.", "#######.", "........",
    ]

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, size in
            let tileSize: CGFloat = 8
            draw(Self.topLeft, at: .zero, in: &context)
            draw(Self.topRight, at: CGPoint(x: size.width - tileSize, y: 0), in: &context)
            draw(Self.bottomLeft, at: CGPoint(x: 0, y: size.height - tileSize), in: &context)
            draw(
                Self.bottomRight,
                at: CGPoint(x: size.width - tileSize, y: size.height - tileSize),
                in: &context
            )

            var horizontalPosition = tileSize
            while horizontalPosition < size.width - tileSize {
                draw(Self.top, at: CGPoint(x: horizontalPosition, y: 0), in: &context)
                draw(Self.bottom, at: CGPoint(x: horizontalPosition, y: size.height - tileSize), in: &context)
                horizontalPosition += tileSize
            }

            var verticalPosition = tileSize
            while verticalPosition < size.height - tileSize {
                draw(Self.left, at: CGPoint(x: 0, y: verticalPosition), in: &context)
                draw(Self.right, at: CGPoint(x: size.width - tileSize, y: verticalPosition), in: &context)
                verticalPosition += tileSize
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(
        _ pattern: [String],
        at origin: CGPoint,
        in context: inout GraphicsContext
    ) {
        for (row, line) in pattern.enumerated() {
            for (column, value) in line.enumerated() where value == "#" {
                let rectangle = CGRect(
                    x: origin.x + CGFloat(column),
                    y: origin.y + CGFloat(row),
                    width: 1,
                    height: 1
                )
                context.fill(Path(rectangle), with: .color(theme.ink))
            }
        }
    }
}

struct AppearancePicker: View {
    @Environment(GameBoyTheme.self) private var theme

    var body: some View {
        @Bindable var theme = theme

        HStack(spacing: 8) {
            ForEach(AppearanceMode.allCases) { mode in
                Button {
                    theme.appearanceMode = mode
                } label: {
                    HStack(spacing: 4) {
                        PixelCursor(isVisible: theme.appearanceMode == mode)
                        Text(mode.title)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PixelOutlineButtonStyle())
                .accessibilityAddTraits(theme.appearanceMode == mode ? .isSelected : [])
            }
        }
    }
}

struct VersionPicker: View {
    @Environment(GameBoyTheme.self) private var theme

    var body: some View {
        @Bindable var theme = theme

        HStack(spacing: 8) {
            ForEach(GameVersion.allCases) { version in
                Button {
                    theme.gameVersion = version
                } label: {
                    HStack(spacing: 6) {
                        PixelCursor(isVisible: theme.gameVersion == version)
                        Text(version.title)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PixelOutlineButtonStyle())
                .accessibilityAddTraits(theme.gameVersion == version ? .isSelected : [])
            }
        }
    }
}

struct PixelCursor: View {
    let isVisible: Bool

    var body: some View {
        Text(isVisible ? "▶" : " ")
            .font(.pixel(.caption))
            .frame(width: 14)
            .accessibilityHidden(true)
    }
}

struct JellySprite: View {
    @Environment(GameBoyTheme.self) private var theme

    private let pixels = [
        ".....AAAA.....",
        "...AAAAAAAA...",
        "..AAAAAAAAAA..",
        ".AAIIIIIIIIAA.",
        "AAIIIIIIIIIIAA",
        "AAIIAIIIIAIIAA",
        "AAIIIIIIIIIIAA",
        "AAIAIIIIIIAIAA",
        ".AAIIIIIIIIAA.",
        "..AAA.AA.AAA..",
        ".AAAA.AA.AAAA.",
        ".AAA..AA..AAA.",
    ]

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, size in
            let columnCount = CGFloat(pixels[0].count)
            let rowCount = CGFloat(pixels.count)
            let unit = min(size.width / columnCount, size.height / rowCount)
            let originX = (size.width - unit * columnCount) / 2
            let originY = (size.height - unit * rowCount) / 2

            for (row, line) in pixels.enumerated() {
                for (column, value) in line.enumerated() where value != "." {
                    let rect = CGRect(
                        x: originX + CGFloat(column) * unit,
                        y: originY + CGFloat(row) * unit,
                        width: ceil(unit),
                        height: ceil(unit)
                    )
                    context.fill(
                        Path(rect),
                        with: .color(value == "A" ? theme.accent : theme.paper)
                    )
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

struct PixelProgressBar: View {
    @Environment(GameBoyTheme.self) private var theme
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(theme.paper)
                Rectangle()
                    .fill(theme.accent)
                    .frame(width: proxy.size.width * min(max(value, 0), 1))
            }
            .overlay { Rectangle().stroke(theme.ink, lineWidth: 2) }
        }
        .frame(height: 8)
        .accessibilityLabel("Played")
        .accessibilityValue("\(Int(value * 100)) percent")
    }
}

struct PixelStateView: View {
    @Environment(GameBoyTheme.self) private var theme
    let title: String
    let detail: String
    var showsProgress = false
    var actionTitle: String?
    var action: (() -> Void)?

    init(
        title: String,
        detail: String,
        showsProgress: Bool = false,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.detail = detail
        self.showsProgress = showsProgress
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 14) {
            if showsProgress {
                Text("...")
                    .font(.pixel(.title))
                    .accessibilityLabel("Loading")
            } else {
                JellySprite().frame(width: 64, height: 64)
            }
            Text(title)
                .font(.pixel(.headline))
            Text(detail)
                .font(.pixel(.caption))
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.secondaryInk)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(PixelButtonStyle(fillsWidth: false))
            }
        }
        .foregroundStyle(theme.ink)
        .frame(maxWidth: 440)
        .frame(maxWidth: .infinity)
        .pixelPanel()
    }
}
