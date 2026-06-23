import SwiftUI

/// Routes first-time users through onboarding, then shows the app shell.
struct AppRootView: View {
    @Bindable var onboardingFlow: OnboardingFlowController
    @Bindable var sidePanel: SidePanelFlowController
    @Bindable var chat: ChatFlowController

    let onThemeToggle: () -> Void

    var body: some View {
        Group {
            if onboardingFlow.state.isFinished {
                HomeView(sidePanel: sidePanel, chat: chat)
            } else {
                OnboardingView(flow: onboardingFlow, onThemeToggle: onThemeToggle)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: onboardingFlow.state.isFinished)
    }
}
