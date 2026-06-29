import Foundation

struct SpeechFlowState: Equatable {
    var isListening = false
    var partialTranscript = ""
    var errorMessage: String?
    var elapsedDuration: TimeInterval = 0
    var audioLevels: [Float] = []
    var isVoiceActive = false
}
