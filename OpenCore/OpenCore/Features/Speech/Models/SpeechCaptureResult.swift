import Foundation

/// Outcome of a completed voice capture — transcript text for the composer draft.
struct SpeechCaptureResult: Equatable, Sendable {
    let composerText: String
}
