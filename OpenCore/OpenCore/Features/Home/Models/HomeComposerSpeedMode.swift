import Foundation

/// Response speed preset for supported models.
nonisolated enum HomeComposerSpeedMode: String, CaseIterable, Equatable, Identifiable, Sendable {
    case standard
    case fast

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard:
            return "Standard"
        case .fast:
            return "Fast"
        }
    }

    var systemImage: String {
        switch self {
        case .standard:
            return "bolt"
        case .fast:
            return "bolt.fill"
        }
    }

    /// OpenRouter `provider.sort.by` value, or `nil` for default routing.
    var providerSortBy: String? {
        switch self {
        case .standard:
            return nil
        case .fast:
            return "throughput"
        }
    }
}
