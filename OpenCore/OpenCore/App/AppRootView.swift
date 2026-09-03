import SwiftUI

/// Routes first-time users through onboarding, then shows the app shell.
struct AppRootView: View {
    @Bindable var onboardingFlow: OnboardingFlowController
    @Bindable var atoms: AtomsFlowController
    @Bindable var home: HomeFlowController
    @Bindable var chat: ChatFlowController
    @Bindable var settings: SettingsFlowController
    @Bindable var speech: SpeechFlowController
    @Bindable var vision: VisionFlowController

    var body: some View {
        Group {
            if onboardingFlow.state.isFinished {
                HomeTabShellView(
                    atoms: atoms,
                    home: home,
                    chat: chat,
                    settings: settings,
                    speech: speech,
                    vision: vision
                )
            } else {
                OnboardingView(onboardingFlow: onboardingFlow)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: onboardingFlow.state.isFinished)
    }
}
