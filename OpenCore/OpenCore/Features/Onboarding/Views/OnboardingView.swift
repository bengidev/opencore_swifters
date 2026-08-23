import SwiftUI

/// Main onboarding view — single-page scene built from the motion spec.
struct OnboardingView: View {
    @Bindable var onboardingFlow: OnboardingFlowController

    var body: some View {
        OnboardingSinglePageView {
            Task {
                await onboardingFlow.finish()
            }
        }
    }
}
