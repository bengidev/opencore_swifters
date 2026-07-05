import Foundation

/// Chooses which message row the thread should scroll to above the composer inset.
nonisolated enum ChatThreadScrollTarget: Sendable {
    static func messageID(in messages: [ChatMessage]) -> UUID? {
        guard let last = messages.last else { return nil }

        if case let .text(textMessage) = last, textMessage.role == .user {
            return last.id
        }

        let turnStart = (messages.lastIndex(where: { $0.role == .user }) ?? -1) + 1
        let currentTurn = messages[turnStart...]

        for message in currentTurn.reversed() {
            switch message {
            case let .text(textMessage) where textMessage.role == .assistant:
                return message.id
            case .outputStream:
                return message.id
            default:
                continue
            }
        }

        return last.id
    }
}
