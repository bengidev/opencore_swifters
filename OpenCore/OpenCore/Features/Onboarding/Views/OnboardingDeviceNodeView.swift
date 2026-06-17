import SwiftUI

/// Device icon card for pairing visualization.
struct OnboardingDeviceNodeIconView: View {
    let systemImage: String
    let active: Bool

    @Environment(\.sharedPalette) private var palette

    static let boxWidth: CGFloat = 76
    static let boxHeight: CGFloat = 92

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(palette.surfaceSubtle.opacity(0.5))
                .frame(width: Self.boxWidth, height: Self.boxHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(active ? palette.accentPrimary.opacity(0.52) : palette.lineSoft, lineWidth: 1)
                )

            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(active ? palette.textPrimary : palette.textTertiary)
                .padding(10)
        }
    }
}

/// Labels shown beneath a device icon card.
struct OnboardingDeviceNodeLabelsView: View {
    let title: String
    let subtitle: String

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(SharedOpenCoreTypography.monoXS)
                .monoTracking()
                .foregroundStyle(palette.textPrimary)
            Text(subtitle)
                .font(.system(size: 8.5, weight: .regular, design: .monospaced))
                .foregroundStyle(palette.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

/// Device card for pairing visualization.
struct OnboardingDeviceNodeView: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let active: Bool

    var body: some View {
        VStack(spacing: 10) {
            OnboardingDeviceNodeIconView(systemImage: systemImage, active: active)
            OnboardingDeviceNodeLabelsView(title: title, subtitle: subtitle)
        }
        .frame(width: 100)
    }
}
