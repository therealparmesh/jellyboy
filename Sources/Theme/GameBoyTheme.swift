import Observation
import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
    var title: String { rawValue.uppercased() }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum GameVersion: String, CaseIterable, Identifiable {
    case blue
    case red

    var id: String { rawValue }
    var title: String { rawValue.uppercased() }
}

struct GBCCompatibilityPalette: Equatable, Sendable {
    let lightest: UInt16
    let light: UInt16
    let dark: UInt16
    let darkest: UInt16

    static let blue = GBCCompatibilityPalette(
        lightest: 0x7FFF,
        light: 0x7E8C,
        dark: 0x7C00,
        darkest: 0x0000
    )

    static let red = GBCCompatibilityPalette(
        lightest: 0x7FFF,
        light: 0x421F,
        dark: 0x1CF2,
        darkest: 0x0000
    )
}

@MainActor
@Observable
final class GameBoyTheme {
    var appearanceMode: AppearanceMode {
        didSet {
            guard persistsChanges else { return }
            defaults.set(appearanceMode.rawValue, forKey: Self.appearanceModeKey)
        }
    }

    var gameVersion: GameVersion {
        didSet {
            guard persistsChanges else { return }
            defaults.set(gameVersion.rawValue, forKey: Self.gameVersionKey)
        }
    }

    var systemColorScheme: ColorScheme = .light

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let persistsChanges: Bool

    init(
        appearanceMode: AppearanceMode? = nil,
        gameVersion: GameVersion? = nil,
        persistsChanges: Bool = true,
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        self.persistsChanges = persistsChanges
        if let appearanceMode {
            self.appearanceMode = appearanceMode
        } else {
            let savedAppearance = defaults.string(forKey: Self.appearanceModeKey)
            let legacyScreenMode = defaults.string(forKey: Self.legacyScreenModeKey)
            self.appearanceMode =
                AppearanceMode(rawValue: savedAppearance ?? "")
                ?? Self.migratedAppearance(from: legacyScreenMode)
        }
        self.gameVersion =
            gameVersion
            ?? GameVersion(rawValue: defaults.string(forKey: Self.gameVersionKey) ?? "")
            ?? .red
    }

    var isDark: Bool {
        switch appearanceMode {
        case .system: systemColorScheme == .dark
        case .light: false
        case .dark: true
        }
    }

    var compatibilityPalette: GBCCompatibilityPalette {
        switch gameVersion {
        case .blue: .blue
        case .red: .red
        }
    }

    var screen: Color {
        Color(rgb555: isDark ? compatibilityPalette.darkest : compatibilityPalette.light)
    }

    var panel: Color {
        Color(rgb555: isDark ? compatibilityPalette.dark : compatibilityPalette.lightest)
    }

    var paper: Color {
        Color(rgb555: isDark ? compatibilityPalette.darkest : compatibilityPalette.lightest)
    }

    var ink: Color {
        Color(rgb555: isDark ? compatibilityPalette.lightest : compatibilityPalette.darkest)
    }

    var mid: Color {
        Color(rgb555: isDark ? compatibilityPalette.light : compatibilityPalette.dark)
    }

    var accent: Color {
        Color(rgb555: isDark ? compatibilityPalette.light : compatibilityPalette.dark)
    }

    var accentSoft: Color {
        Color(rgb555: isDark ? compatibilityPalette.dark : compatibilityPalette.light)
    }

    var secondaryInk: Color { isDark ? ink : mid }
    var disabledFill: Color { accentSoft }
    var pressedFill: Color { accentSoft }
    var selection: Color { accentSoft }
    var posterAccent: Color { accent }
    var disabledControlOpacity: Double { 0.65 }

    private static let appearanceModeKey = "jellyboy.appearance-mode"
    private static let gameVersionKey = "jellyboy.game-version"
    private static let legacyScreenModeKey = "jellyboy.screen-mode"

    private static func migratedAppearance(from legacyValue: String?) -> AppearanceMode {
        switch legacyValue {
        case "night": .dark
        case "day": .light
        default: .system
        }
    }
}

extension Color {
    init(rgb555 value: UInt16) {
        self.init(
            .sRGB,
            red: Double(value & 0x1F) / 31,
            green: Double((value >> 5) & 0x1F) / 31,
            blue: Double((value >> 10) & 0x1F) / 31,
            opacity: 1
        )
    }
}

extension Font {
    static func pixel(_ style: TextStyle = .body) -> Font {
        .custom("jellyboy pixel", size: pixelPointSize(for: style), relativeTo: style)
    }

    private static func pixelPointSize(for style: TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: 28
        case .title: 22
        case .title2: 20
        case .title3, .headline: 17
        case .body: 16
        case .callout: 15
        case .subheadline, .footnote: 13
        case .caption: 12
        case .caption2: 11
        @unknown default: 16
        }
    }
}
