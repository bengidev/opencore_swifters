import Foundation

/// Closure-based boundary for speech recognition.
///
/// This type wraps a `SpeechRecognitionStrategy` into closures so callers
/// can remain strategy-agnostic. Tests and previews can also construct
/// lightweight doubles without a full strategy.
nonisolated struct SpeechRecognitionClient: Sendable {
    var authorizationStatus: @Sendable () -> SpeechAuthorizationStatus
    var requestAuthorization: @Sendable () async -> SpeechAuthorizationStatus
    var start: @Sendable () -> AsyncStream<SpeechRecognitionEvent>
    var stop: @Sendable () async -> SpeechRecognitionResult?

    init(
        authorizationStatus: @escaping @Sendable () -> SpeechAuthorizationStatus,
        requestAuthorization: @escaping @Sendable () async -> SpeechAuthorizationStatus,
        start: @escaping @Sendable () -> AsyncStream<SpeechRecognitionEvent>,
        stop: @escaping @Sendable () async -> SpeechRecognitionResult?
    ) {
        self.authorizationStatus = authorizationStatus
        self.requestAuthorization = requestAuthorization
        self.start = start
        self.stop = stop
    }

    /// Creates a client from a strategy protocol.
    ///
    /// This is the primary initializer for production use. The closure-based
    /// initializer remains available for tests and previews.
    init(strategy: SpeechRecognitionStrategy) {
        self.init(
            authorizationStatus: { strategy.authorizationStatus() },
            requestAuthorization: { await strategy.requestAuthorization() },
            start: { strategy.start() },
            stop: { await strategy.stop() }
        )
    }

    static let preview = SpeechRecognitionClient(
        authorizationStatus: { .authorized },
        requestAuthorization: { .authorized },
        start: { AsyncStream { $0.finish() } },
        stop: { nil }
    )

    /// Construct a live client with the default strategy for the given locale.
    ///
    /// Uses `SpeechRecognitionStrategyFactory.makeDefault()` which selects a
    /// fallback strategy when credentials are available or on-device-only
    /// otherwise.
    static func live(
        locale: Locale = .current,
        credentialStore: CredentialStoring? = nil
    ) -> SpeechRecognitionClient {
        let strategy = SpeechRecognitionStrategyFactory.makeDefault(
            credentialStore: credentialStore,
            locale: locale
        )
        return SpeechRecognitionClient(strategy: strategy)
    }

    /// Construct a live client using an explicit strategy.
    static func live(strategy: SpeechRecognitionStrategy) -> SpeechRecognitionClient {
        SpeechRecognitionClient(strategy: strategy)
    }
}
