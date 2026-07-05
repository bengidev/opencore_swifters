import Foundation

/// Rewrites inline LaTeX into Markdown image links for MarkdownUI image providers.
nonisolated enum ChatAssistantLaTeXPreprocessor: Sendable {
    static let scheme = "opencore-latex"

    static func embedInline(_ markdown: String) -> String {
        guard !markdown.isEmpty else { return markdown }

        var text = markdown
        text = replaceMatches(
            in: text,
            pattern: #"(?<!\$)\$(?!\$)([^\n$]+?)(?<!\$)\$(?!\$)"#,
            transform: { imageMarkdown(latex: $0, isBlock: false) }
        )
        text = replaceMatches(
            in: text,
            pattern: #"\\\((.+?)\\\)"#,
            transform: { imageMarkdown(latex: $0, isBlock: false) }
        )
        return text
    }

    static func decodeLatex(from url: URL) -> (latex: String, isBlock: Bool)? {
        guard url.scheme?.lowercased() == scheme else { return nil }
        guard let latex = url.host?.removingPercentEncoding ?? url.path.removingPercentEncoding else {
            return nil
        }
        let isBlock = url.query?.contains("block=1") == true
        return (latex, isBlock)
    }

    private static func imageMarkdown(latex: String, isBlock: Bool) -> String {
        let encoded = latex.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? latex
        let query = isBlock ? "?block=1" : ""
        return "![latex](\(scheme)://\(encoded)\(query))"
    }

    private static func replaceMatches(
        in text: String,
        pattern: String,
        transform: (String) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: nsRange).reversed()
        var result = text
        for match in matches {
            guard let range = Range(match.range, in: result),
                  match.numberOfRanges > 1,
                  let capture = Range(match.range(at: 1), in: result) else { continue }
            let replacement = transform(String(result[capture]))
            result.replaceSubrange(range, with: replacement)
        }
        return result
    }
}
