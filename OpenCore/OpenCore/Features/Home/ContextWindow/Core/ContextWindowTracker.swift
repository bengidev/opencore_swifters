import Foundation

/// Facade that keeps the latest context window snapshot for a conversation.
nonisolated struct ContextWindowTracker: Equatable, Sendable {
    private(set) var usage: ContextWindowUsage = .zero

    mutating func refresh(
        messages: [ChatMessage],
        draft: String?,
        contextLength: Int?
    ) {
        usage = ContextWindowEstimator.estimate(
            messages: messages,
            draft: draft,
            contextLength: contextLength
        )
    }
}
