import Foundation

/// Resolves the active chat provider into a remote transcription context.
nonisolated enum SpeechRemoteTranscriptionContextResolver {
    nonisolated static func make(
        credentialStore: CredentialStoring,
        providerPreference: SidePanelProviderPreferenceStore
    ) -> @Sendable () -> SpeechRemoteTranscriptionContext? {
        {
            let preference = providerPreference.preference()
            let adapter = ProviderRegistry.resolve(id: preference.providerID)
            let descriptor = adapter.descriptor
            guard credentialStore.secret(for: descriptor.id) != nil else { return nil }
            return SpeechRemoteTranscriptionContext(
                providerID: descriptor.id,
                apiBaseURL: descriptor.baseURL,
                defaultHeaders: descriptor.defaultHeaders
            )
        }
    }
}
