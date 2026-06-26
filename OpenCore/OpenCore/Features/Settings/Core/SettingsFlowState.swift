import Foundation

/// Snapshot of the Settings page: API key draft, stored-key presence,
/// transient errors, provider preference, and context compaction prefs.
nonisolated struct SettingsFlowState: Equatable, Sendable {
    var draftAPIKey = ""
    var hasStoredKey = false
    var errorMessage: String?
    var selectedProviderID: String = ProviderDescriptor.openRouter.id
    var contextCompaction = SettingsContextCompactionPreference()

    var canSave: Bool {
        !draftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(
        draftAPIKey: String = "",
        hasStoredKey: Bool = false,
        errorMessage: String? = nil,
        selectedProviderID: String = ProviderDescriptor.openRouter.id,
        contextCompaction: SettingsContextCompactionPreference = SettingsContextCompactionPreference()
    ) {
        self.draftAPIKey = draftAPIKey
        self.hasStoredKey = hasStoredKey
        self.errorMessage = errorMessage
        self.selectedProviderID = selectedProviderID
        self.contextCompaction = contextCompaction
    }
}
