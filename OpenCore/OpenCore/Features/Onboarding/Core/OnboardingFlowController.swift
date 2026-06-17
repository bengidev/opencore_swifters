import Foundation
import Observation

/// Single entry point for onboarding flow orchestration.
@MainActor
@Observable
final class OnboardingFlowController {
    private(set) var state: OnboardingFlowState
    private let persistence: OnboardingPersistenceClient
    private let invoker = OnboardingCommandInvoker()
    weak var observer: OnboardingFlowObserving?

    init(
        state: OnboardingFlowState = OnboardingFlowState(),
        persistence: OnboardingPersistenceClient = .preview
    ) {
        self.state = state
        self.persistence = persistence
    }

    func onAppear() async {
        let completed = (try? await persistence.isCompleted()) ?? false
        state.isFinished = completed
    }

    func dispatch(_ command: any OnboardingCommand) {
        invoker.invoke(command, on: &state)
    }

    func finish() async {
        state.isFinished = true
        try? await persistence.complete()
        observer?.onboardingDidFinish()
    }
}
