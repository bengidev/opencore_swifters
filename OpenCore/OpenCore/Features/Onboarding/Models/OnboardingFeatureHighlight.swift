import Foundation

/// A feature highlight badge shown at the bottom of onboarding pages.
struct OnboardingFeatureHighlight: Equatable, Sendable, Identifiable {
    var id: String { title }
    let title: String
    let detail: String
    let symbol: String

    init(title: String, detail: String, symbol: String) {
        self.title = title
        self.detail = detail
        self.symbol = symbol
    }
}
