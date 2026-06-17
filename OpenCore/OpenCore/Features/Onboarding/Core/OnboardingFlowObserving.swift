import Foundation

/// Notifies interested parties when onboarding completes.
protocol OnboardingFlowObserving: AnyObject {
    func onboardingDidFinish()
}
