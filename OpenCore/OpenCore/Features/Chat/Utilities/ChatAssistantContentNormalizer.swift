import Foundation

/// Normalizes assistant wire text before it reaches the chat bubble.
nonisolated enum ChatAssistantContentNormalizer {
    static let safetyOnlyFallback =
        "This model returned a safety check instead of an answer. Try another model or rephrase your question."

    static func displayText(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return raw }

        if let extracted = extractFromContentBlocks(trimmed), !extracted.isEmpty {
            return extracted
        }

        if isSafetyOnlyOutput(trimmed) {
            return safetyOnlyFallback
        }

        return raw
    }

    static func isSafetyOnlyOutput(_ text: String) -> Bool {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return false }

        let pattern = /^(?i)(user|response) safety:\s*\S+$/
        return lines.allSatisfy { $0.wholeMatch(of: pattern) != nil }
    }

    static func extractFromContentBlocks(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "[", trimmed.last == "]",
              trimmed.localizedCaseInsensitiveContains("text")
        else {
            return nil
        }

        if let data = trimmed.data(using: .utf8),
           let blocks = try? JSONDecoder().decode([ChatStreamContentPart].self, from: data) {
            let joined = join(blocks)
            if !joined.isEmpty { return joined }
        }

        let regexExtracted = extractTextFields(from: trimmed)
        return regexExtracted.isEmpty ? nil : regexExtracted
    }

    private static func join(_ blocks: [ChatStreamContentPart]) -> String {
        blocks.compactMap(\.renderedText).joined()
    }

    private static func extractTextFields(from blockArray: String) -> String {
        let pattern = /(?:'text'|"text")\s*:\s*(?:"((?:[^"\\]|\\.)*)"|'((?:[^'\\]|\\.)*)')/
        var parts: [String] = []
        for match in blockArray.matches(of: pattern) {
            if let quoted = match.1 {
                parts.append(String(quoted))
            } else if let quoted = match.2 {
                parts.append(String(quoted))
            }
        }
        return parts.joined()
    }
}

nonisolated struct ChatStreamContentPart: Decodable, Sendable, Equatable {
    let type: String?
    let text: String?

    var renderedText: String? {
        guard let text, !text.isEmpty else { return nil }
        switch type {
        case nil, "text", "output_text":
            return text
        default:
            return nil
        }
    }
}
