import Foundation
import Observation

/// Drives the Settings sheet: entering, updating, and clearing the provider API
/// key. The key is persisted to `SidePanelCredentialStore`; this controller
/// never holds the secret beyond the in-flight draft the user is typing, and
/// surfaces only whether a key is stored — never the value itself.
///
/// Persistence (save/clear/reasoningModel/providerID) is dispatched through
/// controller methods rather than commands because each touches the stores.
/// The draft text-field binding uses a command for the pure state mutation.
@MainActor
@Observable
final class SidePanelSettingFlowController {
    private(set) var state: SidePanelSettingFlowState
    private let credentialStore: any SidePanelCredentialStore
    private let providerPreference: any SidePanelProviderPreferenceStore
    private let invoker = SidePanelSettingCommandInvoker()

    /// Fired after a successful save or clear so the parent can refresh its
    /// credential gating without a full state sync.
    var onCredentialsChanged: (() -> Void)?
    /// Fired when the reasoning model is changed so the parent can reload the
    /// model list or update the composer chip.
    var onReasoningModelChanged: (() -> Void)?
    /// Fired when the selected provider changes so the parent can swap the
    /// provider context (model list, credential gate, etc).
    var onProviderChanged: ((String) -> Void)?

    init(
        state: SidePanelSettingFlowState = SidePanelSettingFlowState(),
        credentialStore: any SidePanelCredentialStore,
        providerPreference: any SidePanelProviderPreferenceStore
    ) {
        self.state = state
        self.credentialStore = credentialStore
        self.providerPreference = providerPreference
    }

    // MARK: - Commands (pure state mutations)

    func dispatch(_ command: any SidePanelSettingCommand) {
        invoker.invoke(command, on: &state)
    }

    // MARK: - Actions (touch stores)

    /// Mirrors the persisted preference and stored-key presence into state.
    /// Call once when the sheet appears.
    func onAppear() {
        let preference = providerPreference.preference()
        state.selectedProviderID = preference.providerID ?? SidePanelProviderAPI.default.id
        state.hasStoredKey = credentialStore.secret(for: state.selectedProviderID) != nil
        state.reasoningModel = preference.reasoningModel
    }

    /// Trims the current draft, persists it, and clears the draft field on
    /// success. A blank (whitespace-only) draft is silently ignored.
    func save() {
        let key = state.draftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        do {
            try credentialStore.save(key, for: state.selectedProviderID)
            state.draftAPIKey = ""
            state.hasStoredKey = true
            state.errorMessage = nil
            onCredentialsChanged?()
        } catch {
            state.errorMessage = "Could not save the key to the Keychain."
        }
    }

    /// Removes any stored key for the current provider and resets draft state.
    func clear() {
        do {
            try credentialStore.clear(for: state.selectedProviderID)
            state.draftAPIKey = ""
            state.hasStoredKey = false
            state.errorMessage = nil
            onCredentialsChanged?()
        } catch {
            state.errorMessage = "Could not remove the key from the Keychain."
        }
    }

    /// Persists the reasoning effort tier to the preference store and mirrors
    /// it into local state so the control reflects the change immediately.
    func selectReasoningModel(_ level: SidePanelReasoningModel) {
        providerPreference.setReasoningModel(level)
        state.reasoningModel = level
        onReasoningModelChanged?()
    }

    /// Switches to a different provider, persists the selection, and refreshes
    /// the stored-key indicator for the new provider.
    func selectProvider(_ id: String) {
        providerPreference.setProviderID(id)
        state.selectedProviderID = id
        state.hasStoredKey = credentialStore.secret(for: id) != nil
        onProviderChanged?(id)
    }
}
