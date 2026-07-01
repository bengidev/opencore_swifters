import Foundation
import AVFoundation
import Speech

/// On-device speech recognition using `SFSpeechRecognizer` + `AVAudioEngine`.
///
/// Wraps `SpeechSystemRecognitionEngine` with locale resolution and
/// authorization management. The engine lives on a private actor to
/// serialise access without blocking the caller.
nonisolated final class OnDeviceSpeechRecognitionStrategy: SpeechRecognitionStrategy {
    let identifier = "on-device"

    private let locale: Locale
    private let session: Session

    nonisolated init(locale: Locale = .current) {
        self.locale = locale
        self.session = Session()
    }

    // MARK: - Authorization

    nonisolated func authorizationStatus() -> SpeechAuthorizationStatus {
        SpeechSystemRecognitionEngine.authorizationStatus()
    }

    nonisolated func requestAuthorization() async -> SpeechAuthorizationStatus {
        await SpeechSystemRecognitionEngine.requestAuthorization()
    }

    // MARK: - Recognition
    nonisolated func start() -> AsyncStream<SpeechRecognitionEvent> {
        AsyncStream { continuation in
            Task {
                let stream = await session.start(locale: locale)
                for await event in stream {
                    continuation.yield(event)
                }
                continuation.finish()
            }
        }
    }

    nonisolated func stop() async -> SpeechRecognitionResult? {
        await session.stop()
    }

    // MARK: - Private

    /// Actor that serialises access to the recognition engine.
    private actor Session {
        private var engine: SpeechSystemRecognitionEngine?

        func start(locale: Locale) -> AsyncStream<SpeechRecognitionEvent> {
            let resolvedLocale = Self.resolveLocale(for: locale)
            let engine = SpeechSystemRecognitionEngine(locale: resolvedLocale)
            self.engine = engine
            return engine.start()
        }

        func stop() async -> SpeechRecognitionResult? {
            guard let engine else { return nil }
            self.engine = nil
            return await engine.stop()
        }

        private static func resolveLocale(for preferred: Locale) -> Locale {
            SpeechRecognizerLocaleResolver.resolve(preferred: preferred) { locale in
                guard let recognizer = SFSpeechRecognizer(locale: locale) else { return false }
                return recognizer.isAvailable
            } ?? Locale(identifier: "en-US")
        }
    }
}
