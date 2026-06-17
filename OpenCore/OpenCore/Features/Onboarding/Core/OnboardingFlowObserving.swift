import Foundation

/// Observer pattern — notifies interested parties when onboarding completes.
protocol OnboardingFlowObserving: AnyObject {
    func onboardingDidFinish()
}
