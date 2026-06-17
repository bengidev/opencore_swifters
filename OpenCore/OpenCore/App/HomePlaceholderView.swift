import SwiftUI

/// Placeholder home surface shown after onboarding completes.
struct HomePlaceholderView: View {
    @Environment(\.sharedPalette) private var palette

    var body: some View {
        ZStack {
            palette.surfaceBase.ignoresSafeArea()
            VStack(spacing: 12) {
                Text("OpenCore")
                    .font(SharedOpenCoreTypography.displayMD)
                    .foregroundStyle(palette.textPrimary)
                Text("Workspace ready")
                    .font(SharedOpenCoreTypography.bodyMD)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }
}
