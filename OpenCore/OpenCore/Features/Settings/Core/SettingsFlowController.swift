import Foundation
import Observation

/// Drives the Settings page: provider credentials, context compaction prefs.
@MainActor
@Observable
final class SettingsFlowController {
    private(set) var state: SettingsFlowState
    private let credentialStore: any CredentialStoring
    private let providerPreference: any ProviderPreferenceStore
    private let contextCompactionPreference: any SettingsContextCompactionPreferenceStore
    private let invoker = SettingsCommandInvoker()

    var onCredentialsChanged: (() -> Void)?
    var onProviderChanged: ((String) -> Void)?
    var onContextCompactionChanged: (() -> Void)?

    init(
        state: SettingsFlowState = SettingsFlowState(),
        credentialStore: any CredentialStoring,
        providerPreference: any ProviderPreferenceStore,
        contextCompactionPreference: any SettingsContextCompactionPreferenceStore = SettingsUserDefaultsContextCompactionPreferenceStore()
    ) {
        self.state = state
        self.credentialStore = credentialStore
        self.providerPreference = providerPreference
        self.contextCompactionPreference = contextCompactionPreference
    }

    func dispatch(_ command: any SettingsCommand) {
        invoker.invoke(command, on: &state)
        if command is SettingsContextCompactionEnabledChangedCommand
            || command is SettingsContextCompactionReserveTokensChangedCommand
            || command is SettingsContextCompactionKeepRecentTokensChangedCommand {
            persistContextCompaction()
        }
    }

    func onAppear() {
        let preference = providerPreference.preference()
        state.selectedProviderID = preference.providerID ?? ProviderDescriptor.openRouter.id
        state.hasStoredKey = credentialStore.secret(for: state.selectedProviderID) != nil
        state.contextCompaction = contextCompactionPreference.preference()
    }

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

    func selectProvider(_ id: String) {
        providerPreference.setProviderID(id)
        state.selectedProviderID = id
        state.hasStoredKey = credentialStore.secret(for: id) != nil
        onProviderChanged?(id)
    }

    func setContextCompactionEnabled(_ isEnabled: Bool) {
        dispatch(SettingsContextCompactionEnabledChangedCommand(isEnabled: isEnabled))
    }

    func setContextCompactionReserveTokens(_ tokens: Int) {
        let clamped = min(32_768, max(4_096, tokens))
        dispatch(SettingsContextCompactionReserveTokensChangedCommand(reserveTokens: clamped))
    }

    func setContextCompactionKeepRecentTokens(_ tokens: Int) {
        let clamped = min(40_960, max(4_096, tokens))
        dispatch(SettingsContextCompactionKeepRecentTokensChangedCommand(keepRecentTokens: clamped))
    }

    private func persistContextCompaction() {
        contextCompactionPreference.setPreference(state.contextCompaction)
        onContextCompactionChanged?()
    }
}
