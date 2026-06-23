import Foundation

/// Persisted message kind discriminator. Mirrors the three `ChatMessage`
/// domain cases so the enum can be reconstructed losslessly at the client
/// boundary without leaking SwiftData types into the domain.
enum ChatMessageKind: String, Codable, Sendable {
    case text
    case thinking
    case system
}
