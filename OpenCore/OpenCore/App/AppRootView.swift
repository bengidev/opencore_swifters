import SwiftUI

/// Routes first-time users through onboarding, then shows the app shell.
struct AppRootView: View {
    @Bindable var onboardingFlow: OnboardingFlowController
    @Bindable var sidePanel: SidePanelFlowController
    @Bindable var home: HomeFlowController
    @Bindable var chat: ChatFlowController
    @Bindable var settings: SettingsFlowController
    @Bindable var speech: SpeechFlowController

    let onThemeToggle: () -> Void

    var body: some View {
        Group {
            if onboardingFlow.state.isFinished {
                HomeTabShellView(
                    sidePanel: sidePanel,
                    home: home,
                    chat: chat,
                    settings: settings,
                    speech: speech
                )
            } else {
                OnboardingView(flow: onboardingFlow, onThemeToggle: onThemeToggle)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: onboardingFlow.state.isFinished)
    }
}
