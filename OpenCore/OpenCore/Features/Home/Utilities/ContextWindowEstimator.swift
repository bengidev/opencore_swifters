import Foundation

/// Token estimation backed by Tiktoken (`cl100k_base`) when available.
nonisolated enum ContextWindowEstimator {
    static func estimate(
        messages: [ChatMessage],
        draft: String?,
        contextLength: Int?
    ) -> ContextWindowUsage {
        let tokensUsed = ContextTokenCounter.countTokens(for: messages, draft: draft)
        return ContextWindowUsage(
            tokensUsed: tokensUsed,
            tokenLimit: contextLength ?? 0
        )
    }

    static func shouldCompact(
        messages: [ChatMessage],
        draft: String?,
        contextLength: Int,
        reserveTokens: Int
    ) -> Bool {
        guard contextLength > 0 else { return false }
        let tokensUsed = ContextTokenCounter.countTokens(for: messages, draft: draft)
        return tokensUsed > max(0, contextLength - reserveTokens)
    }

    static func shouldCompact(
        messages: [ChatMessage],
        draft: String?,
        contextLength: Int,
        thresholdPercent: Int
    ) -> Bool {
        guard contextLength > 0, thresholdPercent > 0 else { return false }
        let tokensUsed = ContextTokenCounter.countTokens(for: messages, draft: draft)
        return tokensUsed * 100 > contextLength * thresholdPercent
    }
}
