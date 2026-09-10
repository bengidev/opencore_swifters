import SwiftUI

/// Shared raised-card chrome for categorized chat stream bubbles.
struct ChatMessageCardChrome<Content: View>: View {
    @Environment(\.sharedPalette) private var palette
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surfaceRaised.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(palette.textTertiary.opacity(0.12), lineWidth: 0.5)
            )
    }
}

struct ChatMessageCardHeader: View {
    let icon: String
    let title: String
    var showsPulse: Bool = false

    @Environment(\.sharedPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.accentPrimary)
                .accessibilityHidden(true)

            Text(title)
                .font(SharedOpenCoreTypography.monoSM)
                .foregroundStyle(palette.textSecondary)
                .monoTracking()

            if showsPulse {
                ChatStreamingPulseDot()
            }

            Spacer(minLength: 8)
        }
    }
}
