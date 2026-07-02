import Foundation

/// Transcribes audio captured by another recognition strategy.
///
/// Used by `FallbackSpeechRecognitionStrategy` when on-device streaming
/// produces no usable transcript but audio was recorded.
nonisolated protocol SpeechPostRecordingTranscriber: Sendable {
    func transcribe(
        audioFileURL: URL,
        waveformSamples: [Float],
        duration: TimeInterval
    ) async -> SpeechRecognitionResult?
}
