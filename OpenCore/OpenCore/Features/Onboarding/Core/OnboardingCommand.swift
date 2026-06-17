import Foundation

/// Command pattern — encapsulates onboarding mutations as executable objects.
protocol OnboardingCommand: Sendable {
    func execute(
        on state: inout OnboardingFlowState,
        using strategies: OnboardingPageBehaviorStrategyFactory
    )
}

struct OnboardingAdvancePageCommand: OnboardingCommand {
    func execute(
        on state: inout OnboardingFlowState,
        using strategies: OnboardingPageBehaviorStrategyFactory
    ) {
        let nextPage = min(state.currentPage + 1, state.totalPages - 1)
        state.currentPage = nextPage
        strategies.strategy(for: OnboardingPage.all[nextPage].type)?.applyDefaults(to: &state)
    }
}

struct OnboardingRetreatPageCommand: OnboardingCommand {
    func execute(
        on state: inout OnboardingFlowState,
        using strategies: OnboardingPageBehaviorStrategyFactory
    ) {
        let previousPage = max(state.currentPage - 1, 0)
        state.currentPage = previousPage
        strategies.strategy(for: OnboardingPage.all[previousPage].type)?.applyDefaults(to: &state)
    }
}

struct OnboardingSelectPageCommand: OnboardingCommand {
    let index: Int

    func execute(
        on state: inout OnboardingFlowState,
        using strategies: OnboardingPageBehaviorStrategyFactory
    ) {
        let selectedPage = min(max(index, 0), state.totalPages - 1)
        state.currentPage = selectedPage
        strategies.strategy(for: OnboardingPage.all[selectedPage].type)?.applyDefaults(to: &state)
    }
}

struct OnboardingSkipToLastPageCommand: OnboardingCommand {
    func execute(
        on state: inout OnboardingFlowState,
        using strategies: OnboardingPageBehaviorStrategyFactory
    ) {
        state.currentPage = state.totalPages - 1
    }
}

struct OnboardingSelectPromptChipCommand: OnboardingCommand {
    let index: Int

    func execute(
        on state: inout OnboardingFlowState,
        using strategies: OnboardingPageBehaviorStrategyFactory
    ) {
        state.selectedPromptIndex = min(
            max(index, 0),
            OnboardingPromptOption.samples.count - 1
        )
    }
}

struct OnboardingIncrementQueueCommand: OnboardingCommand {
    func execute(
        on state: inout OnboardingFlowState,
        using strategies: OnboardingPageBehaviorStrategyFactory
    ) {
        state.queuedPromptCount = state.queuedPromptCount >= OnboardingQueueItem.samples.count
            ? 2
            : state.queuedPromptCount + 1
    }
}

struct OnboardingSetReasoningLevelCommand: OnboardingCommand {
    let level: Double

    func execute(
        on state: inout OnboardingFlowState,
        using strategies: OnboardingPageBehaviorStrategyFactory
    ) {
        state.reasoningLevel = min(max(level, 0), 1)
    }
}

struct OnboardingTogglePairingCommand: OnboardingCommand {
    func execute(
        on state: inout OnboardingFlowState,
        using strategies: OnboardingPageBehaviorStrategyFactory
    ) {
        state.pairingConfirmed.toggle()
    }
}

/// Invoker — dispatches commands without exposing mutation rules to callers.
struct OnboardingCommandInvoker: Sendable {
    let strategyFactory: OnboardingPageBehaviorStrategyFactory

    func invoke(_ command: any OnboardingCommand, on state: inout OnboardingFlowState) {
        command.execute(on: &state, using: strategyFactory)
    }
}
