import Foundation

/// Strategy pattern — page-specific demo defaults applied when entering a page.
protocol OnboardingPageBehaviorStrategy: Sendable {
    func applyDefaults(to state: inout OnboardingFlowState)
}

struct OnboardingIdeaStudioPageStrategy: OnboardingPageBehaviorStrategy {
    func applyDefaults(to state: inout OnboardingFlowState) {
        state.selectedPromptIndex = OnboardingDemoDefaults.selectedPromptIndex
    }
}

struct OnboardingReasoningControlPageStrategy: OnboardingPageBehaviorStrategy {
    func applyDefaults(to state: inout OnboardingFlowState) {
        state.reasoningLevel = OnboardingDemoDefaults.reasoningLevel
    }
}

/// Factory Method — selects the strategy for a page type.
struct OnboardingPageBehaviorStrategyFactory: Sendable {
    func strategy(for pageType: OnboardingPageType) -> (any OnboardingPageBehaviorStrategy)? {
        switch pageType {
        case .ideaStudio:
            OnboardingIdeaStudioPageStrategy()
        case .reasoningControl:
            OnboardingReasoningControlPageStrategy()
        case .encryptedPairing, .promptQueue, .workspaceReady:
            nil
        }
    }
}
