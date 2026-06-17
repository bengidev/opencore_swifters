import Foundation

/// Snapshot of onboarding flow data mutated through commands.
struct OnboardingFlowState: Equatable, Sendable {
    var currentPage = 0
    var isFinished = false
    var selectedPromptIndex = 0
    var queuedPromptCount = 2
    var reasoningLevel = OnboardingDemoDefaults.reasoningLevel
    var pairingConfirmed = true

    var totalPages: Int { OnboardingPage.all.count }
    var isLastPage: Bool { currentPage >= totalPages - 1 }

    var currentPageData: OnboardingPage {
        let safeIndex = min(max(currentPage, 0), totalPages - 1)
        return OnboardingPage.all[safeIndex]
    }
}
