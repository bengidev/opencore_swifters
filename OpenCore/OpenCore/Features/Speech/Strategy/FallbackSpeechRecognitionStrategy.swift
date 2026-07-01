import Foundation

/// Composite strategy that tries on-device recognition first and falls back
/// to remote (Whisper) transcription when on-device produces an empty
/// transcript or fails with a retryable error.
///
/// The fallback transcribes the audio already captured by the on-device
/// strategy through `RemoteSpeechRecognitionStrategy.transcribe()` — no
/// re-recording needed.
///
/// This strategy is transparent to `SpeechFlowController` — callers use the
/// same protocol regardless of which backend ultimately handles the audio.
nonisolated final class FallbackSpeechRecognitionStrategy: SpeechRecognitionStrategy {
    let identifier = "fallback"

    private let primary: OnDeviceSpeechRecognitionStrategy
    private let remote: RemoteSpeechRecognitionStrategy

    init(
        primary: OnDeviceSpeechRecognitionStrategy,
        remote: RemoteSpeechRecognitionStrategy
    ) {
        self.primary = primary
        self.remote = remote
    }

    // MARK: - Authorization

    nonisolated func authorizationStatus() -> SpeechAuthorizationStatus {
        primary.authorizationStatus()
    }

    nonisolated func requestAuthorization() async -> SpeechAuthorizationStatus {
        await primary.requestAuthorization()
    }

    // MARK: - Recognition

    nonisolated func start() -> AsyncStream<SpeechRecognitionEvent> {
        primary.start()
    }

    nonisolated func stop() async -> SpeechRecognitionResult? {
        let primaryResult = await primary.stop()

        // If primary produced a good transcript, use it directly.
        if let primaryResult,
           !primaryResult.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return primaryResult
        }

        // Primary recorded audio but got no usable transcript — fall back
        // by sending the captured audio to the remote Whisper API.
        if let primaryResult, let audioURL = primaryResult.audioFileURL {
            return await remote.transcribe(
                audioFileURL: audioURL,
                waveformSamples: primaryResult.waveformSamples,
                duration: primaryResult.duration
            )
        }

        // No audio captured at all — nothing to fall back on.
        return primaryResult
    }
}
