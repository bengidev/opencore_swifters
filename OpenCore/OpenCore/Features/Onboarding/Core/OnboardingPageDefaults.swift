import Foundation

/// Applies page-specific demo defaults when the user navigates to a page.
enum OnboardingPageDefaults {
    static func apply(for pageType: OnboardingPageType, to state: inout OnboardingFlowState) {
        switch pageType {
        case .ideaStudio:
            state.selectedPromptIndex = OnboardingDemoDefaults.selectedPromptIndex
        case .reasoningControl:
            state.reasoningLevel = OnboardingDemoDefaults.reasoningLevel
        case .encryptedPairing, .promptQueue, .workspaceReady:
            break
        }
    }
}
