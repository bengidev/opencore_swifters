import SwiftUI

/// Factory Method — builds page-specific demo visuals.
enum OnboardingPageVisualFactory {
    @MainActor
    @ViewBuilder
    static func make(
        page: OnboardingPage,
        flow: OnboardingFlowController,
        appeared: Bool
    ) -> some View {
        switch page.type {
        case .encryptedPairing:
            OnboardingEncryptedPairingVisualView(
                isConfirmed: flow.state.pairingConfirmed,
                appeared: appeared,
                onToggle: { flow.dispatch(OnboardingTogglePairingCommand()) }
            )

        case .ideaStudio:
            OnboardingIdeaStudioVisualView(
                selectedPromptIndex: flow.state.selectedPromptIndex,
                appeared: appeared,
                onPromptSelected: { flow.dispatch(OnboardingSelectPromptChipCommand(index: $0)) }
            )

        case .promptQueue:
            OnboardingPromptQueueVisualView(
                queuedPromptCount: flow.state.queuedPromptCount,
                appeared: appeared
            )

        case .reasoningControl:
            OnboardingReasoningControlVisualView(
                reasoningLevel: Binding(
                    get: { flow.state.reasoningLevel },
                    set: { flow.dispatch(OnboardingSetReasoningLevelCommand(level: $0)) }
                ),
                appeared: appeared
            )

        case .workspaceReady:
            OnboardingWorkspaceReadyVisualView(
                page: page,
                appeared: appeared
            )
        }
    }
}
