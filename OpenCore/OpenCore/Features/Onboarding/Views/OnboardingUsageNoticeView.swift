import SwiftUI

/// Explains default-key limits and BYOK before the onboarding swipe CTA.
struct OnboardingUsageNoticeView: View {
    @Environment(\.sharedPalette) private var palette

    var body: some View {
        Text("The default key is free to start with, but daily token and turn limits apply. Bring your own API key (BYOK) in Settings for higher limits and full provider access.")
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .accessibilityIdentifier("onboarding-usage-notice")
    }
}

#Preview {
    OnboardingUsageNoticeView()
        .padding(20)
        .environment(\.sharedPalette, SharedOpenCorePalette.resolve(.light))
}
