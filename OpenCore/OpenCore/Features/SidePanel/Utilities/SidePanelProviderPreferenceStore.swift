import Foundation

/// The persisted selection of provider and model.
///
/// Pure value data: a provider id (matching a `ProviderDescriptor` in the
/// catalog) plus a dynamic model id string. The model id is intentionally a
/// free-form string — model identity is no longer a closed enum, so any model
/// the provider exposes can be selected without a code change.
nonisolated struct SidePanelProviderPreference: Equatable, Sendable {
    /// Stable provider identifier (e.g. `"openrouter"`). Defaults to the
    /// default provider.
    var providerID: String?
    /// Dynamic model identifier (e.g. `"meta-llama/llama-3.3-70b-instruct:free"`).
    /// `nil` until a model is selected; send is gated until this is set.
    var modelID: String?
    /// Persisted reasoning effort wire value. `nil` omits reasoning on requests.
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

// MARK: - Store abstraction

/// A minimal store for the provider/model preference.
///
/// This is the single source of truth for which provider and model the app
/// sends with. The live adapter persists to `UserDefaults`; an in-memory double
/// backs tests and previews.
///
/// The preference is read lazily (`preference()`), never cached by callers, so
/// a change made in one surface takes effect on the next read with no stale
/// value — mirroring how `CredentialStoring` resolves the secret per request.
nonisolated protocol SidePanelProviderPreferenceStore: Sendable {
    /// The current stored preference.
    func preference() -> SidePanelProviderPreference
    /// Persists the selected provider id.
    func setProviderID(_ providerID: String?)
    /// Persists the selected model id.
    func setModelID(_ modelID: String?)
    /// Persists the selected reasoning effort wire value (`nil` = off).
    func setReasoningEffort(_ effort: ModelReasoningEffort)
}

// MARK: - UserDefaults adapter

/// Live `SidePanelProviderPreferenceStore` backed by `UserDefaults`.
nonisolated struct SidePanelUserDefaultsProviderPreferenceStore: SidePanelProviderPreferenceStore {
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

    func preference() -> SidePanelProviderPreference {
        let stored = defaults.string(forKey: Key.reasoningLevel) ?? "high"
        return SidePanelProviderPreference(
            providerID: nonEmpty(defaults.string(forKey: Key.providerID)),
            modelID: nonEmpty(defaults.string(forKey: Key.modelID)),
            reasoningEffortWireValue: SidePanelReasoningModel.migrateStoredValue(stored)
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
            defaults.set(SidePanelReasoningModel.off.rawValue, forKey: Key.reasoningLevel)
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - In-memory test double

/// Thread-safe in-memory `SidePanelProviderPreferenceStore` for tests and previews.
nonisolated final class SidePanelInMemoryProviderPreferenceStore: SidePanelProviderPreferenceStore, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: SidePanelProviderPreference

    init(preference: SidePanelProviderPreference = SidePanelProviderPreference()) {
        self.stored = preference
    }

    func preference() -> SidePanelProviderPreference {
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
