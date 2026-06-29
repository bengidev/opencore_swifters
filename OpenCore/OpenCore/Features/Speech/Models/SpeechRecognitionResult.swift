import Foundation

/// Speech stop payload — transcript for model input, audio for bubble display.
nonisolated struct SpeechRecognitionResult: Equatable, Sendable {
    let transcript: String
    let audioFileURL: URL?
    let waveformSamples: [Float]
    let duration: TimeInterval

    init(
        transcript: String,
        audioFileURL: URL? = nil,
        waveformSamples: [Float] = [],
        duration: TimeInterval = 0
    ) {
        self.transcript = transcript
        self.audioFileURL = audioFileURL
        self.waveformSamples = waveformSamples
        self.duration = duration
    }
}
