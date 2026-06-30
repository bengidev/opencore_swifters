import SwiftUI

/// Subtle monochrome luminance shift overlay with sine wave offset — technical signal glitch effect.
struct SharedSignalGlitchModifier: ViewModifier {
    let progress: Double
    let intensity: Double

    @Environment(\.sharedPalette) private var palette

    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.effectGlitchHighlight.opacity(0.07 * intensity),
                                Color.clear,
                                palette.effectGlitchHighlight.opacity(0.04 * intensity)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            )
            .offset(x: sin(progress * .pi * 4) * 0.5 * intensity)
    }
}

extension View {
    func signalGlitch(progress: Double, intensity: Double = 1) -> some View {
        modifier(SharedSignalGlitchModifier(progress: progress, intensity: intensity))
    }
}
