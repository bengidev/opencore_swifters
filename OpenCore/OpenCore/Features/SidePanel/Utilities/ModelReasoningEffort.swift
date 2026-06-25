import Foundation

/// A reasoning-effort option for a model, sourced from the provider catalog.
nonisolated struct ModelReasoningEffort: Equatable, Hashable, Identifiable, Sendable, Codable {
    /// Wire value sent to the provider, or `nil` to omit the reasoning parameter.
    let wireValue: String?

    var id: String { wireValue ?? "off" }

    var title: String {
        guard let wireValue else { return "Off" }
        return Self.displayTitle(for: wireValue)
    }

    /// Value placed on the request, or `nil` when reasoning should be omitted.
    var requestEffort: String? { wireValue }

    static let off = ModelReasoningEffort(wireValue: nil)

    static func displayTitle(for wireValue: String) -> String {
        switch wireValue {
        case "none":
            return "None"
        case "minimal":
            return "Minimal"
        case "xhigh":
            return "Extra High"
        case "max":
            return "Max"
        default:
            return wireValue.prefix(1).uppercased() + wireValue.dropFirst()
        }
    }

    /// Builds menu options from catalog `supported_efforts`, appending Off when the
    /// model allows disabling reasoning and the catalog does not list `none`.
    static func catalogOptions(from wireEfforts: [String], reasoningMandatory: Bool) -> [ModelReasoningEffort] {
        guard !wireEfforts.isEmpty else { return [] }
        var options = wireEfforts.map { ModelReasoningEffort(wireValue: $0) }
        if !reasoningMandatory, !wireEfforts.contains("none") {
            options.append(.off)
        }
        return options
    }

    /// Picks a stored effort that is valid for the model, or a sensible default.
    static func resolvedSelection(
        storedWireValue: String?,
        available: [ModelReasoningEffort]
    ) -> ModelReasoningEffort {
        guard !available.isEmpty else { return .off }
        if let storedWireValue,
           let match = available.first(where: { $0.wireValue == storedWireValue }) {
            return match
        }
        if storedWireValue == nil,
           available.contains(where: { $0.wireValue == nil }) {
            return .off
        }
        if let high = available.first(where: { $0.wireValue == "high" }) {
            return high
        }
        return available.first(where: { $0.wireValue != nil }) ?? available[0]
    }
}
