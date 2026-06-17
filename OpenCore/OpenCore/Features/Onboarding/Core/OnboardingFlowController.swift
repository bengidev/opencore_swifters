import Foundation
import Observation

/// Single entry point for onboarding flow orchestration.
@MainActor
@Observable
final class OnboardingFlowController {
    private(set) var state: OnboardingFlowState
    private let persistence: OnboardingPersistenceClient
    private let invoker = OnboardingCommandInvoker()

    init(
        state: OnboardingFlowState = OnboardingFlowState(),
        persistence: OnboardingPersistenceClient = .preview
    ) {
        self.state = state
        self.persistence = persistence
    }

    func onAppear() async {
        do {
            state.isFinished = try await persistence.isCompleted()
        } catch {
            state.isFinished = false
        }
    }

    func dispatch(_ command: any OnboardingCommand) {
        invoker.invoke(command, on: &state)
    }

    @discardableResult
    func finish() async -> Bool {
        do {
            try await persistence.complete()
            state.isFinished = true
            return true
        } catch {
            return false
        }
    }
}
