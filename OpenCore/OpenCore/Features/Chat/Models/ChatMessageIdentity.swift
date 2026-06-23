import Foundation

nonisolated enum ChatMessageRole: String, Equatable, Sendable, Codable {
    case user
    case assistant
    case system
}

nonisolated enum ChatStreamingStatus: Equatable, Sendable {
    case idle
    case running
    case done
    case failed
}
