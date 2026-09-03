import Foundation

/// The persisted selection of provider and model.
nonisolated struct ProviderPreference: Equatable, Sendable {
    var providerID: String?
    var modelID: String?
    var reasoningEffortWireValue: String?

    init(
        providerID: String? = ProviderDescriptor.openRouter.id,
        modelID: String? = nil,
        reasoningEffortWireValue: String? = "high"
    ) {
        self.providerID = providerID
        self.modelID = modelID
        self.reasoningEffortWireValue = reasoningEffortWireValue
    }
}

nonisolated protocol ProviderPreferenceStore: Sendable {
    func preference() -> ProviderPreference
    func setProviderID(_ providerID: String?)
    func setModelID(_ modelID: String?)
    func setReasoningEffort(_ effort: ModelReasoningEffort)
}

nonisolated struct UserDefaultsProviderPreferenceStore: ProviderPreferenceStore {
    let suiteName: String?

    private enum Key {
        static let providerID = "opencore.provider.selectedProviderID"
        static let modelID = "opencore.provider.selectedModelID"
        static let reasoningLevel = "opencore.provider.reasoningLevel"
    }

    init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    func preference() -> ProviderPreference {
        let stored = defaults.string(forKey: Key.reasoningLevel) ?? "high"
        return ProviderPreference(
            providerID: nonEmpty(defaults.string(forKey: Key.providerID)),
            modelID: nonEmpty(defaults.string(forKey: Key.modelID)),
            reasoningEffortWireValue: LegacyReasoningLevel.migrateStoredValue(stored)
        )
    }

    func setProviderID(_ providerID: String?) {
        if let providerID = nonEmpty(providerID) {
            defaults.set(providerID, forKey: Key.providerID)
        } else {
            defaults.removeObject(forKey: Key.providerID)
        }
    }

    func setModelID(_ modelID: String?) {
        if let modelID = nonEmpty(modelID) {
            defaults.set(modelID, forKey: Key.modelID)
        } else {
            defaults.removeObject(forKey: Key.modelID)
        }
    }

    func setReasoningEffort(_ effort: ModelReasoningEffort) {
        if let wireValue = effort.wireValue {
            defaults.set(wireValue, forKey: Key.reasoningLevel)
        } else {
            defaults.set(LegacyReasoningLevel.off.rawValue, forKey: Key.reasoningLevel)
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

nonisolated final class InMemoryProviderPreferenceStore: ProviderPreferenceStore, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: ProviderPreference

    init(preference: ProviderPreference = ProviderPreference()) {
        self.stored = preference
    }

    func preference() -> ProviderPreference {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func setProviderID(_ providerID: String?) {
        lock.lock()
        defer { lock.unlock() }
        stored.providerID = providerID
    }

    func setModelID(_ modelID: String?) {
        lock.lock()
        defer { lock.unlock() }
        stored.modelID = modelID
    }

    func setReasoningEffort(_ effort: ModelReasoningEffort) {
        lock.lock()
        defer { lock.unlock() }
        stored.reasoningEffortWireValue = effort.wireValue
    }
}

/// Legacy persisted reasoning tiers. New code stores wire values via
/// `ProviderPreference.reasoningEffortWireValue`.
nonisolated enum LegacyReasoningLevel: String, Equatable, Sendable, Codable {
    case off
    case low
    case medium
    case high

    var wireValue: String? {
        switch self {
        case .off: return nil
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        }
    }

    static func migrateStoredValue(_ raw: String) -> String? {
        if let legacy = LegacyReasoningLevel(rawValue: raw) {
            return legacy.wireValue
        }
        if raw == "off" || raw.isEmpty {
            return nil
        }
        return raw
    }
}
