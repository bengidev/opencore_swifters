import Foundation

/// Provider-scoped configuration for post-recording Whisper transcription.
nonisolated struct SpeechRemoteTranscriptionContext: Equatable, Sendable {
    let providerID: String
    let apiBaseURL: URL
    let defaultHeaders: [String: String]

    var audioTranscriptionsURL: URL {
        apiBaseURL.appendingPathComponent("audio/transcriptions")
    }
}
