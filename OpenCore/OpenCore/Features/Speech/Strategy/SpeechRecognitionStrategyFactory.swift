import Foundation

/// Factory for constructing `SpeechRecognitionStrategy` instances.
///
/// Separates strategy construction from the rest of the speech module so
/// callers (primarily `SpeechRecognitionClient`) get the right strategy
/// without knowing the concrete types.
nonisolated enum SpeechRecognitionStrategyFactory {
    /// Build a strategy appropriate for the available infrastructure.
    ///
    /// - If a credential store with a Whisper API key is available, returns
    ///   a fallback strategy (on-device → remote). Otherwise returns an
    ///   on-device-only strategy.
    /// - Parameter credentialStore: Optional credential store to resolve
    ///   Whisper API keys. When `nil`, the factory defaults to on-device only.
    nonisolated static func makeDefault(
        credentialStore: CredentialStoring? = nil,
        locale: Locale = .current,
        urlSession: URLSession = .shared
    ) -> SpeechRecognitionStrategy {
        guard let credentialStore else {
            return makeOnDeviceOnly(locale: locale)
        }

        let onDevice = OnDeviceSpeechRecognitionStrategy(locale: locale)
        let remote = RemoteSpeechRecognitionStrategy(
            credentialStore: credentialStore,
            urlSession: urlSession
        )

        return FallbackSpeechRecognitionStrategy(primary: onDevice, remote: remote)
    }

    /// On-device recognition only — no network dependency.
    nonisolated static func makeOnDeviceOnly(locale: Locale = .current) -> SpeechRecognitionStrategy {
        OnDeviceSpeechRecognitionStrategy(locale: locale)
    }

    /// Remote-only recognition — useful when the device lacks speech support.
    nonisolated static func makeRemoteOnly(
        credentialStore: CredentialStoring,
        urlSession: URLSession = .shared
    ) -> SpeechRecognitionStrategy {
        RemoteSpeechRecognitionStrategy(
            credentialStore: credentialStore,
            urlSession: urlSession
        )
    }
}
