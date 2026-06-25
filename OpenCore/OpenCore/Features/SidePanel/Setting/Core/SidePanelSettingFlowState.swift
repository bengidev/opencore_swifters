import Foundation

/// Snapshot of the Settings sheet: entered key draft, stored-key presence,
/// transient errors, and the persisted reasoning / provider preference mirrored
/// from the shared stores.
nonisolated struct SidePanelSettingFlowState: Equatable, Sendable {
    /// The in-progress value bound to the secure field. Cleared after a
    /// successful save so the secret does not linger in feature state.
    var draftAPIKey = ""
    /// Whether a key is currently stored. Drives the "saved" affordance and
    /// the parent send-gate.
    var hasStoredKey = false
    /// Transient error surfaced when a Keychain write fails.
    var errorMessage: String?
    /// Persisted reasoning effort wire value mirrored from the preference store.
    var reasoningEffortWireValue: String? = "high"
    /// Catalog-driven reasoning options for the selected model.
    var availableReasoningEfforts: [ModelReasoningEffort] = []
    /// The provider whose credentials are currently being managed. Defaults to
    /// the catalog default so the control always has a valid selection.
    var selectedProviderID: String = ProviderDescriptor.openRouter.id

    var canSave: Bool {
        !draftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var selectedReasoningEffort: ModelReasoningEffort {
        ModelReasoningEffort.resolvedSelection(
            storedWireValue: reasoningEffortWireValue,
            available: availableReasoningEfforts
        )
    }

    init(
        draftAPIKey: String = "",
        hasStoredKey: Bool = false,
        errorMessage: String? = nil,
        reasoningEffortWireValue: String? = "high",
        availableReasoningEfforts: [ModelReasoningEffort] = [],
        selectedProviderID: String = ProviderDescriptor.openRouter.id
    ) {
        self.draftAPIKey = draftAPIKey
        self.hasStoredKey = hasStoredKey
        self.errorMessage = errorMessage
        self.reasoningEffortWireValue = reasoningEffortWireValue
        self.availableReasoningEfforts = availableReasoningEfforts
        self.selectedProviderID = selectedProviderID
    }
}
