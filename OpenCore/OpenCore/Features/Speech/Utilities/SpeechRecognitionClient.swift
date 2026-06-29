import Foundation

/// Closure-based boundary for on-device speech recognition.
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

    static let preview = SpeechRecognitionClient(
        authorizationStatus: { .authorized },
        requestAuthorization: { .authorized },
        start: { AsyncStream { $0.finish() } },
        stop: { nil }
    )

    static func live(locale: Locale = .current) -> SpeechRecognitionClient {
        actor Session {
            private var engine: SpeechSystemRecognitionEngine?

            func start(locale: Locale) -> AsyncStream<SpeechRecognitionEvent> {
                let engine = engine ?? SpeechSystemRecognitionEngine(locale: locale)
                self.engine = engine
                return engine.start()
            }

            func stop() async -> SpeechRecognitionResult? {
                guard let engine else { return nil }
                self.engine = nil
                return await engine.stop()
            }
        }

        let session = Session()
        let locale = locale

        return SpeechRecognitionClient(
            authorizationStatus: { SpeechSystemRecognitionEngine.authorizationStatus() },
            requestAuthorization: { await SpeechSystemRecognitionEngine.requestAuthorization() },
            start: {
                AsyncStream { continuation in
                    Task {
                        let stream = await session.start(locale: locale)
                        for await event in stream {
                            continuation.yield(event)
                        }
                        continuation.finish()
                    }
                }
            },
            stop: { await session.stop() }
        )
    }
}
