import SwiftUI

/// Feature highlight row with a palette-aware generative orb and editorial copy.
struct OnboardingFeatureCardView: View {
    let feature: OnboardingFeature

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        HStack(spacing: 16) {
            featureOrb

            VStack(alignment: .leading, spacing: 3) {
                Text(feature.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)

                Text(feature.subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.surfacePaper.opacity(palette.isDark ? 0.88 : 1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(palette.lineSoft, lineWidth: 1)
        )
    }

    private var featureOrb: some View {
        let orbColors = feature.orbColors(palette: palette)
        let iconColor = palette.isDark ? palette.surfaceBase : palette.controlStrongText

        return ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        colors: orbColors + [orbColors[0]],
                        center: .center
                    )
                )
                .blur(radius: palette.isDark ? 6 : 4)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            (palette.isDark ? Color.white : palette.controlStrongText)
                                .opacity(palette.isDark ? 0.55 : 0.35),
                            .clear
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 24
                    )
                )

            Image(systemName: feature.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .shadow(color: palette.elevation(.chip), radius: 2, y: 1)
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
        .overlay(
            Circle()
                .strokeBorder(palette.lineSoft.opacity(palette.isDark ? 0.55 : 0.85), lineWidth: 1)
        )
    }
}
