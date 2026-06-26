import Foundation

/// Tabs presented by the home shell.
nonisolated enum HomeTab: String, CaseIterable, Equatable, Sendable {
    case home
    case settings
    case about
}
