import SwiftUI

/// OpenCore design system palette — monochrome: neutral paper base, graphite accent, ink controls.
/// Fully grayscale (hue-less) ramp; hierarchy carried by lightness and contrast.
struct SharedOpenCorePalette: Sendable {
    let isDark: Bool

    // MARK: - Surfaces

    /// Main app background — cool off-white / deep blue-black
    let surfaceBase: Color
    /// Paper-like sections — slightly tinted base
    let surfacePaper: Color
    /// Raised panels, grouped content
    let surfaceRaised: Color
    /// Secondary fills, quiet containers
    let surfaceSubtle: Color
    /// Very light neutral wash for selected fields
    let surfaceGalaxyTint: Color

    // MARK: - Text

    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color

    // MARK: - Lines

    let lineSoft: Color
    let lineStrong: Color

    // MARK: - Accent (graphite)

    /// Active state, progress, current step, command hint
    let accentPrimary: Color
    /// Pressed accent, strong selection
    let accentDeep: Color
    /// Accent background, quiet highlight
    let accentSoft: Color

    // MARK: - Controls

    /// Primary CTA fill (graphite/near-black)
    let controlStrong: Color
    /// Text on strong controls
    let controlStrongText: Color

    // MARK: - Status

    let success: Color
    let warning: Color
    let danger: Color

    // MARK: - Effects

    /// Light source for screen-blend overlays (glitch, shimmer).
    let effectGlitchHighlight: Color

    /// Dark scrim behind controls overlaid on photos or media.
    let mediaControlScrim: Color
    let mediaControlIcon: Color

    /// Disabled primary control fill (e.g. send button).
    var controlDisabledFill: Color {
        surfaceGalaxyTint.opacity(isDark ? 0.55 : 0.95)
    }

    enum ElevationLevel: Sendable {
        case chip
        case popover
        case composerChrome(lightOpacity: Double)
    }

    /// Drop shadow for elevated surfaces — stronger in dark mode for visible depth.
    func elevationShadow(lightOpacity: Double, darkOpacity: Double? = nil) -> Color {
        Color.black.opacity(isDark ? (darkOpacity ?? min(lightOpacity * 3, 0.5)) : lightOpacity)
    }

    /// Named elevation tiers so call sites don't invent opacity multipliers.
    func elevation(_ level: ElevationLevel) -> Color {
        switch level {
        case .chip:
            elevationShadow(lightOpacity: 0.06)
        case .popover:
            elevationShadow(lightOpacity: 0.12, darkOpacity: 0.35)
        case .composerChrome(let lightOpacity):
            elevationShadow(lightOpacity: lightOpacity, darkOpacity: min(lightOpacity * 2.5, 0.4))
        }
    }

    /// Tap-outside scrim overlay.
    func scrimOverlay(opacity: Double) -> Color {
        Color.black.opacity(isDark ? min(opacity * 2.5, 0.35) : opacity)
    }

    struct ComposerGlassTokens: Sendable {
        let fill: Color
        let usesUltraThinMaterial: Bool
        let strokeOpacity: Double
        let shadow: Color
    }

    func composerGlass(shadowOpacity: Double) -> ComposerGlassTokens {
        ComposerGlassTokens(
            fill: isDark ? surfacePaper.opacity(0.85) : surfaceRaised,
            usesUltraThinMaterial: isDark,
            strokeOpacity: isDark ? 0.35 : 0.55,
            shadow: elevation(.composerChrome(lightOpacity: shadowOpacity))
        )
    }

    /// Resolve palette for the given color scheme.
    static func resolve(_ scheme: ColorScheme) -> SharedOpenCorePalette {
        if scheme == .dark {
            return SharedOpenCorePalette(
                isDark: true,
                surfaceBase: Color(hex: "0B0B0B"),
                surfacePaper: Color(hex: "121212"),
                surfaceRaised: Color(hex: "1A1A1A"),
                surfaceSubtle: Color(hex: "242424"),
                surfaceGalaxyTint: Color(hex: "2C2C2C"),
                textPrimary: Color(hex: "F5F5F5"),
                textSecondary: Color(hex: "B0B0B0"),
                textTertiary: Color(hex: "7E7E7E"),
                lineSoft: Color(hex: "2E2E2E"),
                lineStrong: Color(hex: "484848"),
                accentPrimary: Color(hex: "DADADA"),
                accentDeep: Color(hex: "F4F4F4"),
                accentSoft: Color(hex: "2C2C2C"),
                controlStrong: Color(hex: "F5F5F5"),
                controlStrongText: Color(hex: "121212"),
                success: Color(hex: "B5B5B5"),
                warning: Color(hex: "CECECE"),
                danger: Color(hex: "EDEDED"),
                effectGlitchHighlight: Color(hex: "F5F5F5"),
                mediaControlScrim: Color.black.opacity(0.55),
                mediaControlIcon: Color.white
            )
        }

        return SharedOpenCorePalette(
            isDark: false,
            surfaceBase: Color(hex: "F7F7F7"),
            surfacePaper: Color(hex: "F1F1F1"),
            surfaceRaised: Color(hex: "FFFFFF"),
            surfaceSubtle: Color(hex: "EAEAEA"),
            surfaceGalaxyTint: Color(hex: "E2E2E2"),
            textPrimary: Color(hex: "141414"),
            textSecondary: Color(hex: "6E6E6E"),
            textTertiary: Color(hex: "9C9C9C"),
            lineSoft: Color(hex: "E0E0E0"),
            lineStrong: Color(hex: "BEBEBE"),
            accentPrimary: Color(hex: "2B2B2B"),
            accentDeep: Color(hex: "0F0F0F"),
            accentSoft: Color(hex: "E2E2E2"),
            controlStrong: Color(hex: "141414"),
            controlStrongText: Color(hex: "FFFFFF"),
            success: Color(hex: "4A4A4A"),
            warning: Color(hex: "333333"),
            danger: Color(hex: "1A1A1A"),
            effectGlitchHighlight: Color.white,
            mediaControlScrim: Color.black.opacity(0.72),
            mediaControlIcon: Color.white
        )
    }
}
