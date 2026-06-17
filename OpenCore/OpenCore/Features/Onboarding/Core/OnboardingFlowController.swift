import Foundation
import Observation

/// Facade + Observer — single entry point for onboarding flow orchestration.
@MainActor
@Observable
final class OnboardingFlowController {
    private(set) var state: OnboardingFlowState
    private let persistence: OnboardingPersistenceClient
    private let invoker: OnboardingCommandInvoker
    weak var observer: OnboardingFlowObserving?

    init(
        state: OnboardingFlowState = OnboardingFlowState(),
        persistence: OnboardingPersistenceClient = .preview,
        strategyFactory: OnboardingPageBehaviorStrategyFactory = OnboardingPageBehaviorStrategyFactory()
    ) {
        self.state = state
        self.persistence = persistence
        self.invoker = OnboardingCommandInvoker(strategyFactory: strategyFactory)
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
