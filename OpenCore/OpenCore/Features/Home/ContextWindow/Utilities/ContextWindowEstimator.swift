import Foundation

/// Character-based token estimation strategy until provider usage events land.
nonisolated enum ContextWindowEstimator {
    static func estimate(
        messages: [ChatMessage],
        draft: String?,
        contextLength: Int?
    ) -> ContextWindowUsage {
        var tokensUsed = messages.reduce(0) { partial, message in
            partial + estimatedTokens(for: messageText(message))
        }

        if let draft {
            tokensUsed += estimatedTokens(for: draft)
        }

        return ContextWindowUsage(
            tokensUsed: tokensUsed,
            tokenLimit: contextLength ?? 0
        )
    }

    private static func messageText(_ message: ChatMessage) -> String {
        switch message {
        case let .text(textMessage):
            guard textMessage.isComplete else { return "" }
            return textMessage.content
        case let .thinking(thinkingMessage):
            guard thinkingMessage.isComplete else { return "" }
            return thinkingMessage.content
        case let .system(systemMessage):
            return systemMessage.content
        }
    }

    private static func estimatedTokens(for text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        return (trimmed.count + 3) / 4
    }
}
