import SwiftUI

/// Compact status chip above the composer while a response is streaming.
struct ChatStreamingStatusCapsuleView: View {
    @Environment(\.sharedPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dotOpacity = 0.35

    var body: some View {
        HStack(spacing: 6) {
            Text("Processing")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.textSecondary)

            Circle()
                .fill(palette.textSecondary)
                .frame(width: 6, height: 6)
                .opacity(reduceMotion ? 1 : dotOpacity)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(palette.surfaceRaised)
        )
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Processing, streaming")
        .accessibilityAddTraits(.updatesFrequently)
        .onAppear { startDotAnimation() }
    }

    private func startDotAnimation() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            dotOpacity = 1
        }
    }
}
