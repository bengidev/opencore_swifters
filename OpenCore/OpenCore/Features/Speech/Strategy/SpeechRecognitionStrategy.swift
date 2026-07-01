import Foundation

/// Strategy protocol for speech-to-text backends.
///
/// Conformances model a recognition strategy — on-device Apple Speech,
/// remote Whisper API, or a composite that falls back between them.
/// Each strategy owns its lifecycle: authorization, streaming recognition,
/// and final result collection.
///
/// - Note: All methods must be safe to call from any actor or queue.
nonisolated protocol SpeechRecognitionStrategy: Sendable {
    /// Stable identifier for diagnostics and logging.
    var identifier: String { get }

    /// Current system authorization status for this strategy's backend.
    func authorizationStatus() -> SpeechAuthorizationStatus

    /// Request authorization if needed; returns the resolved status.
    func requestAuthorization() async -> SpeechAuthorizationStatus

    /// Begin recognition and return a live event stream.
    ///
    /// The stream emits `.ready` when recording starts, `.partial`/`.final`
    /// for incremental results, `.audioLevel` for waveform data, and
    /// `.failed` on unrecoverable error. The stream finishes when
    /// recognition ends or an error occurs.
    func start() -> AsyncStream<SpeechRecognitionEvent>

    /// Stop recognition and return the final transcription result.
    ///
    /// - Returns: The final `SpeechRecognitionResult` containing transcript,
    ///   audio file URL, waveform samples, and duration, or `nil` if
    ///   recognition was cancelled or produced no useful output.
    func stop() async -> SpeechRecognitionResult?
}
