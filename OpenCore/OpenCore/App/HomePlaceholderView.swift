import SwiftUI

/// Placeholder home surface shown after onboarding completes.
struct HomePlaceholderView: View {
    let onThemeToggle: () -> Void

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        ZStack {
            palette.surfaceBase.ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    SharedThemeToggleButton(onTap: onThemeToggle)
                        .accessibilityLabel("Toggle appearance")
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                Text("OpenCore")
                    .font(SharedOpenZoneTypography.displayMD)
                    .foregroundStyle(palette.textPrimary)
                Text("Workspace ready")
                    .font(SharedOpenZoneTypography.bodyMD)
                    .foregroundStyle(palette.textSecondary)

                Spacer()
            }
        }
    }
}
