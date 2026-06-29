import Foundation

enum SpeechRecognitionEvent: Equatable, Sendable {
    case ready
    case partial(String)
    case final(String)
    case failed(String)
    case audioLevel(Float)
}
