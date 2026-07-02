import Foundation

/// Factory for constructing `SpeechRecognitionStrategy` instances.
///
/// Separates strategy construction from the rest of the speech module so
/// callers (primarily `SpeechRecognitionClient`) get the right strategy
/// without knowing the concrete types.
nonisolated enum SpeechRecognitionStrategyFactory {
    /// Build a strategy appropriate for the available infrastructure.
    ///
    /// Returns a fallback strategy (on-device → remote Whisper) only when the
    /// active provider has a stored API key. Otherwise returns on-device only.
    nonisolated static func makeDefault(
        credentialStore: CredentialStoring? = nil,
        transcriptionContext: @escaping @Sendable () -> SpeechRemoteTranscriptionContext? = { nil },
        locale: Locale = .current,
        urlSession: URLSession = .shared
    ) -> SpeechRecognitionStrategy {
        guard let credentialStore else {
            return makeOnDeviceOnly(locale: locale)
        }

        let remote = RemoteSpeechRecognitionStrategy(
            credentialStore: credentialStore,
            contextResolver: transcriptionContext,
            urlSession: urlSession
        )

        guard remote.hasCredential() else {
            return makeOnDeviceOnly(locale: locale)
        }

        let onDevice = OnDeviceSpeechRecognitionStrategy(locale: locale)

        return FallbackSpeechRecognitionStrategy(
            primary: onDevice,
            remoteTranscriber: remote
        )
    }

    /// On-device recognition only — no network dependency.
    nonisolated static func makeOnDeviceOnly(locale: Locale = .current) -> SpeechRecognitionStrategy {
        OnDeviceSpeechRecognitionStrategy(locale: locale)
    }
}
