import SwiftUI

/// Theme toggle control — cycles through system/light/dark with sliding thumb animation.
struct SharedThemeToggleButton: View {
    @Environment(\.sharedPalette) private var palette
    @Environment(\.sharedAppTheme) private var appTheme
    @Environment(\.onThemeToggle) private var onThemeToggle

    private var isSystemMode: Bool {
        appTheme == .system
    }

    private var resolvedIsDark: Bool {
        palette.isDark
    }

    var body: some View {
        Button(action: onThemeToggle) {
            ZStack {
                // Track
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(palette.surfaceSubtle.opacity(0.5))
                    .frame(width: 32, height: 28)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(
                                isSystemMode ? palette.lineStrong : palette.lineSoft,
                                lineWidth: isSystemMode ? 0.8 : 0.5
                            )
                    )

                // Sliding thumb
                HStack {
                    if resolvedIsDark, !isSystemMode {
                        Spacer()
                    }

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(palette.accentPrimary)
                        .frame(width: 11, height: 22)
                        .shadow(
                            color: palette.accentPrimary.opacity(isSystemMode ? 0.30 : 0.50),
                            radius: isSystemMode ? 2 : 4,
                            x: 0,
                            y: 2
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(
                                    isSystemMode
                                        ? palette.textPrimary.opacity(0.08)
                                        : palette.textPrimary.opacity(0.18),
                                    lineWidth: 0.5
                                )
                        )
                        .padding(.horizontal, isSystemMode ? 11 : 3)

                    if !resolvedIsDark, !isSystemMode {
                        Spacer()
                    }
                }
                .frame(width: 32, height: 28)
            }
            .frame(width: 32, height: 28)
        }
        .buttonStyle(SharedThemeToggleButtonStyle(palette: palette))
        .accessibilityLabel("Theme")
        .accessibilityValue(appTheme.displayName)
        .accessibilityHint("Cycles between System, Light, and Dark.")
    }
}

/// Preserves the sliding-thumb press animation (`scaleEffect` on press/release)
/// that the previous tap-gesture implementation animated manually.
private struct SharedThemeToggleButtonStyle: ButtonStyle {
    let palette: SharedOpenCorePalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}
