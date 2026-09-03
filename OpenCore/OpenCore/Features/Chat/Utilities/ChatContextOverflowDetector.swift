import Foundation

/// Detects provider errors that indicate the request exceeded the model context window.
nonisolated enum ChatContextOverflowDetector {
    private static let patterns = [
        "context length",
        "context window",
        "maximum context",
        "max context",
        "token limit",
        "too many tokens",
        "prompt is too long",
        "request too large",
        "context_length_exceeded",
        "maximum number of tokens"
    ]

    static func isContextOverflow(_ message: String) -> Bool {
        let normalized = message.lowercased()
        return patterns.contains { normalized.contains($0) }
    }
}
