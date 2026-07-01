import Foundation

struct SpeechFlowState: Equatable {
    var isListening = false
    var isTranscribing = false
    /// Frozen waveform shown while post-stop transcription runs.
    var transcribingWaveformSamples: [Float] = []
    var transcribingDuration: TimeInterval = 0
    var partialTranscript = ""
    var errorMessage: String?
    var elapsedDuration: TimeInterval = 0
    var audioLevels: [Float] = []
    var isVoiceActive = false
}
