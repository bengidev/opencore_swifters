import Foundation

/// Legacy persisted reasoning tiers. New code stores wire values via
/// `SidePanelProviderPreference.reasoningEffortWireValue`.
nonisolated enum SidePanelReasoningModel: String, Equatable, Sendable, Codable {
    case off
    case low
    case medium
    case high

    var wireValue: String? {
        switch self {
        case .off:
            return nil
        case .low:
            return "low"
        case .medium:
            return "medium"
        case .high:
            return "high"
        }
    }

    static func migrateStoredValue(_ raw: String) -> String? {
        if let legacy = SidePanelReasoningModel(rawValue: raw) {
            return legacy.wireValue
        }
        if raw == "off" || raw.isEmpty {
            return nil
        }
        return raw
    }
}
