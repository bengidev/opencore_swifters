import Foundation

/// Encapsulates a single onboarding flow mutation.
protocol OnboardingCommand: Sendable {
    func execute(on state: inout OnboardingFlowState)
}

struct OnboardingFinishCommand: OnboardingCommand {
    func execute(on state: inout OnboardingFlowState) {
        state.isFinished = true
    }
}

/// Dispatches onboarding commands without exposing mutation rules to callers.
struct OnboardingCommandInvoker: Sendable {
    func invoke(_ command: any OnboardingCommand, on state: inout OnboardingFlowState) {
        command.execute(on: &state)
    }
}
