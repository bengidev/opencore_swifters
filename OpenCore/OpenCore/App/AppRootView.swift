import SwiftUI

/// Routes first-time users through onboarding, then shows the app shell.
struct AppRootView: View {
    @Bindable var onboardingFlow: OnboardingFlowController
    @Bindable var sidePanel: SidePanelFlowController
    @Bindable var home: HomeFlowController
    @Bindable var chat: ChatFlowController

    let onThemeToggle: () -> Void

    var body: some View {
        Group {
            if onboardingFlow.state.isFinished {
                HomeView(sidePanel: sidePanel, home: home, chat: chat)
            } else {
                OnboardingView(flow: onboardingFlow, onThemeToggle: onThemeToggle)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: onboardingFlow.state.isFinished)
    }
}
