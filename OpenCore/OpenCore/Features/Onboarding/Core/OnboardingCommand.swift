import Foundation

/// Encapsulates a single onboarding flow mutation.
protocol OnboardingCommand: Sendable {
    func execute(on state: inout OnboardingFlowState)
}

struct OnboardingAdvancePageCommand: OnboardingCommand {
    func execute(on state: inout OnboardingFlowState) {
        let nextPage = min(state.currentPage + 1, state.totalPages - 1)
        state.currentPage = nextPage
        OnboardingPageDefaults.apply(for: OnboardingPage.all[nextPage].type, to: &state)
    }
}

struct OnboardingRetreatPageCommand: OnboardingCommand {
    func execute(on state: inout OnboardingFlowState) {
        let previousPage = max(state.currentPage - 1, 0)
        state.currentPage = previousPage
        OnboardingPageDefaults.apply(for: OnboardingPage.all[previousPage].type, to: &state)
    }
}

struct OnboardingSelectPageCommand: OnboardingCommand {
    let index: Int

    func execute(on state: inout OnboardingFlowState) {
        let selectedPage = min(max(index, 0), state.totalPages - 1)
        state.currentPage = selectedPage
        OnboardingPageDefaults.apply(for: OnboardingPage.all[selectedPage].type, to: &state)
    }
}

struct OnboardingSkipToLastPageCommand: OnboardingCommand {
    func execute(on state: inout OnboardingFlowState) {
        let lastPage = state.totalPages - 1
        state.currentPage = lastPage
        OnboardingPageDefaults.apply(for: OnboardingPage.all[lastPage].type, to: &state)
    }
}

struct OnboardingSelectPromptChipCommand: OnboardingCommand {
    let index: Int

    func execute(on state: inout OnboardingFlowState) {
        state.selectedPromptIndex = min(
            max(index, 0),
            OnboardingPromptOption.samples.count - 1
        )
    }
}

struct OnboardingIncrementQueueCommand: OnboardingCommand {
    func execute(on state: inout OnboardingFlowState) {
        state.queuedPromptCount = state.queuedPromptCount >= OnboardingQueueItem.samples.count
            ? 2
            : state.queuedPromptCount + 1
    }
}

struct OnboardingSetReasoningLevelCommand: OnboardingCommand {
    let level: Double

    func execute(on state: inout OnboardingFlowState) {
        state.reasoningLevel = min(max(level, 0), 1)
    }
}

struct OnboardingTogglePairingCommand: OnboardingCommand {
    func execute(on state: inout OnboardingFlowState) {
        state.pairingConfirmed.toggle()
    }
}

/// Dispatches onboarding commands without exposing mutation rules to callers.
struct OnboardingCommandInvoker: Sendable {
    func invoke(_ command: any OnboardingCommand, on state: inout OnboardingFlowState) {
        command.execute(on: &state)
    }
}
