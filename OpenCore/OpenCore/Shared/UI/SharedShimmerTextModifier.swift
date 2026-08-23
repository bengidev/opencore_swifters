import SwiftUI

/// Sweeping luminance highlight across text — palette-aware screen-blend shimmer.
struct SharedShimmerTextModifier: ViewModifier {
    let baseColor: Color
    let isActive: Bool

    @Environment(\.sharedPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmerOffset: CGFloat = -1

    private let sweepDuration: Double = 1.75
    private let sweepBandWidthRatio: CGFloat = 0.55

    func body(content: Content) -> some View {
        if isActive && !reduceMotion {
            content
                .foregroundStyle(baseColor)
                .overlay {
                    GeometryReader { proxy in
                        let bandWidth = max(proxy.size.width * sweepBandWidthRatio, 24)
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: palette.effectGlitchHighlight.opacity(0.2), location: 0.38),
                                .init(color: palette.effectGlitchHighlight.opacity(0.95), location: 0.5),
                                .init(color: palette.effectGlitchHighlight.opacity(0.2), location: 0.62),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: bandWidth)
                        .offset(x: shimmerOffset * (proxy.size.width + bandWidth))
                        .blendMode(.screen)
                    }
                    .mask(content)
                }
                .onAppear { startShimmerLoop() }
                .onChange(of: isActive) { _, active in
                    if active {
                        startShimmerLoop()
                    }
                }
        } else {
            content
                .foregroundStyle(baseColor)
        }
    }

    private func startShimmerLoop() {
        shimmerOffset = -1
        withAnimation(.linear(duration: sweepDuration).repeatForever(autoreverses: false)) {
            shimmerOffset = 1
        }
    }
}

extension View {
    func shimmeringText(baseColor: Color, isActive: Bool = true) -> some View {
        modifier(SharedShimmerTextModifier(baseColor: baseColor, isActive: isActive))
    }
}
