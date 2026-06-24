import Foundation

/// Normalized context window load for the active conversation and model.
nonisolated struct ContextWindowUsage: Equatable, Sendable {
    static let zero = ContextWindowUsage(tokensUsed: 0, tokenLimit: 0)

    let tokensUsed: Int
    let tokenLimit: Int

    init(tokensUsed: Int, tokenLimit: Int) {
        self.tokenLimit = max(0, tokenLimit)
        let rawUsed = max(0, tokensUsed)
        self.tokensUsed = self.tokenLimit > 0 ? min(rawUsed, self.tokenLimit) : rawUsed
    }

    var hasKnownLimit: Bool { tokenLimit > 0 }

    var tokensRemaining: Int {
        guard hasKnownLimit else { return 0 }
        return max(0, tokenLimit - tokensUsed)
    }

    var fractionUsed: Double {
        guard hasKnownLimit else { return 0 }
        return min(1, Double(tokensUsed) / Double(tokenLimit))
    }

    var percentUsed: Int {
        Int((fractionUsed * 100).rounded())
    }

    var percentRemaining: Int {
        guard hasKnownLimit else { return 0 }
        return max(0, 100 - percentUsed)
    }

    var tokensUsedFormatted: String {
        Self.compactTokenLabel(tokensUsed)
    }

    var tokenLimitFormatted: String {
        Self.compactTokenLabel(tokenLimit)
    }

    var tokensRemainingFormatted: String {
        Self.compactTokenLabel(tokensRemaining)
    }

    var ringCenterLabel: String {
        hasKnownLimit ? "\(percentUsed)" : "—"
    }

    var accessibilitySummary: String {
        hasKnownLimit
            ? "\(percentUsed)% used, \(percentRemaining)% left"
            : "\(tokensUsedFormatted) used"
    }

    var popoverBadgeText: String {
        hasKnownLimit ? "\(percentRemaining)% left" : "\(tokensUsedFormatted) used"
    }

    var showsUsageBreakdown: Bool { hasKnownLimit }

    var tokenSummaryLabel: String {
        "\(tokensUsedFormatted) / \(tokenLimitFormatted) tokens"
    }

    private static func compactTokenLabel(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            return formatCompact(Double(tokens) / 1_000_000, suffix: "M")
        }
        if tokens >= 1_000 {
            return formatCompact(Double(tokens) / 1_000, suffix: "K")
        }
        return "\(tokens)"
    }

    private static func formatCompact(_ value: Double, suffix: String) -> String {
        let oneDecimal = (value * 10).rounded() / 10
        if abs(oneDecimal - oneDecimal.rounded()) < 0.001 {
            return "\(Int(oneDecimal))\(suffix)"
        }
        return String(format: "%.1f", oneDecimal) + suffix
    }
}
