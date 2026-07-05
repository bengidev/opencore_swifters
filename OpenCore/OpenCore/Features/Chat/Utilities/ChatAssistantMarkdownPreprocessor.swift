import Foundation

/// Normalizes assistant markdown so streamed prose breaks into readable sections.
nonisolated enum ChatAssistantMarkdownPreprocessor: Sendable {
    static func normalize(_ markdown: String) -> String {
        guard !markdown.isEmpty else { return markdown }

        let segments = markdown.components(separatedBy: "```")
        let normalized = segments.enumerated().map { index, segment in
            index.isMultiple(of: 2) ? normalizeProseSegment(segment) : segment
        }
        return normalized.joined(separator: "```")
    }

    private static func normalizeProseSegment(_ segment: String) -> String {
        var text = segment

        text = text.replacingOccurrences(
            of: #"(?<=[.!?])(\*\*[^*\n]{2,80}:\*\*)"#,
            with: "\n\n$1",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"(?<=[^\n])(\*\*[^*\n]{2,80}:\*\*)"#,
            with: "\n\n$1",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"(?<=[^\n])(#{1,6}\s+\S[^\n]*)"#,
            with: "\n\n$1",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"(?<=[^\n])(——+\s*\*\*)"#,
            with: "\n\n$1",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"(?<=[.!?])\s+([-•*]\s+)"#,
            with: "\n\n$1",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"(?<=\S)\s+([-•*]\s+\S)"#,
            with: "\n\n$1",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"(?<=\S)\s+(\d+\.\s+\S)"#,
            with: "\n\n$1",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"<br\s*/?>"#,
            with: " ",
            options: [.regularExpression, .caseInsensitive]
        )
        text = ensureGFMTableSpacing(text)

        return text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
            .replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
    }

    private static func ensureGFMTableSpacing(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"(?<=\S)\n(\|[^\n]+\|)\n(\|[ :\-|]+\|)"#,
            with: "\n\n$1\n$2",
            options: .regularExpression
        )
    }
}
