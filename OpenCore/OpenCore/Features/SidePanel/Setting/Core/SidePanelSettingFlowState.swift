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
    /// The persisted reasoning effort tier, mirrored from the preference store.
    var reasoningModel: SidePanelReasoningModel = .high
    /// Whether the currently selected model supports reasoning. Seeded by the
    /// parent when presenting the sheet.
    var modelSupportsReasoning = false
    /// The provider whose credentials are currently being managed. Defaults to
    /// the catalog default so the control always has a valid selection.
    var selectedProviderID: String = SidePanelProviderAPI.default.id

    var canSave: Bool {
        !draftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(
        draftAPIKey: String = "",
        hasStoredKey: Bool = false,
        errorMessage: String? = nil,
        reasoningModel: SidePanelReasoningModel = .high,
        modelSupportsReasoning: Bool = false,
        selectedProviderID: String = SidePanelProviderAPI.default.id
    ) {
        self.draftAPIKey = draftAPIKey
        self.hasStoredKey = hasStoredKey
        self.errorMessage = errorMessage
        self.reasoningModel = reasoningModel
        self.modelSupportsReasoning = modelSupportsReasoning
        self.selectedProviderID = selectedProviderID
    }
}
