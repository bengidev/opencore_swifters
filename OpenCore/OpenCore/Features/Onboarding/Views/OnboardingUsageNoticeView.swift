import SwiftUI

/// Explains default-key limits and BYOK before the onboarding swipe CTA.
struct OnboardingUsageNoticeView: View {
    static let accessibilityTestIdentifier = "onboarding-usage-notice"

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        Text(Self.noticeCopy)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .accessibilityIdentifier(Self.accessibilityTestIdentifier)
            .accessibilityLabel(Self.voiceOverCopy)
    }

    static let noticeCopy =
        "The default key is free to start with, but daily token and turn limits apply. Bring your own API key (BYOK) in Settings for higher limits and full provider access."

    static let voiceOverCopy =
        "The default key is free to start with, but daily token and turn limits apply. Bring your own API key in Settings for higher limits and full provider access."
}

#Preview {
    OnboardingUsageNoticeView()
        .padding(20)
        .environment(\.sharedPalette, SharedOpenCorePalette.resolve(.light))
}
