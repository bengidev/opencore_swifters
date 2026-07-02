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
        let session = session
        return AsyncStream { continuation in
            let forwardingTask = Task {
                let stream = await session.start(locale: locale)
                for await event in stream {
                    guard !Task.isCancelled else { break }
                    continuation.yield(event)
                }
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in
                forwardingTask.cancel()
                Task {
                    await session.stopIfActive()
                }
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
        private var lastStopResult: SpeechRecognitionResult?

        func start(locale: Locale) -> AsyncStream<SpeechRecognitionEvent> {
            lastStopResult = nil
            let resolvedLocale = Self.resolveLocale(for: locale)
            let engine = SpeechSystemRecognitionEngine(locale: resolvedLocale)
            self.engine = engine
            return engine.start()
        }

        func stop() async -> SpeechRecognitionResult? {
            guard let engine else { return lastStopResult }
            self.engine = nil
            let result = await engine.stop()
            lastStopResult = result
            return result
        }

        /// Stops only when the caller did not already stop explicitly.
        func stopIfActive() async {
            guard engine != nil else { return }
            _ = await stop()
        }

        private static func resolveLocale(for preferred: Locale) -> Locale {
            SpeechRecognizerLocaleResolver.resolve(preferred: preferred) { locale in
                guard let recognizer = SFSpeechRecognizer(locale: locale) else { return false }
                return recognizer.isAvailable
            } ?? Locale(identifier: "en-US")
        }
    }
}
