import Foundation

/// Snapshot of the Settings page: entered key draft, stored-key presence,
/// transient errors, and the persisted provider preference mirrored from the
/// shared stores.
nonisolated struct SidePanelSettingFlowState: Equatable, Sendable {
    /// The in-progress value bound to the secure field. Cleared after a
    /// successful save so the secret does not linger in feature state.
    var draftAPIKey = ""
    /// Whether a key is currently stored. Drives the "saved" affordance and
    /// the parent send-gate.
    var hasStoredKey = false
    /// Transient error surfaced when a Keychain write fails.
    var errorMessage: String?
    /// The provider whose credentials are currently being managed. Defaults to
    /// the catalog default so the control always has a valid selection.
    var selectedProviderID: String = ProviderDescriptor.openRouter.id

    var canSave: Bool {
        !draftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(
        draftAPIKey: String = "",
        hasStoredKey: Bool = false,
        errorMessage: String? = nil,
        selectedProviderID: String = ProviderDescriptor.openRouter.id
    ) {
        self.draftAPIKey = draftAPIKey
        self.hasStoredKey = hasStoredKey
        self.errorMessage = errorMessage
        self.selectedProviderID = selectedProviderID
    }
}
