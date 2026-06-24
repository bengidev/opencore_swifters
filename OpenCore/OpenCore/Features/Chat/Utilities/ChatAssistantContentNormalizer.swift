import Foundation

/// Normalizes assistant wire text before it reaches the chat bubble.
nonisolated enum ChatAssistantContentNormalizer {
    static let safetyOnlyFallback =
        "This model returned a safety check instead of an answer. Try another model or rephrase your question."

  private static func isSafetyLine(_ line: String) -> Bool {
        line.wholeMatch(of: /^(?i)(user|response) safety:\s*\S+$/) != nil
    }

    static func displayText(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return raw }

        if let extracted = extractFromContentBlocks(trimmed), !extracted.isEmpty {
            return extracted
        }

        let withoutSafetyHeaders = stripSafetyHeaderLines(from: trimmed)
        if withoutSafetyHeaders != trimmed {
            if let extracted = extractFromContentBlocks(withoutSafetyHeaders), !extracted.isEmpty {
                return extracted
            }
            if !withoutSafetyHeaders.isEmpty, !isSafetyOnlyOutput(trimmed) {
                return withoutSafetyHeaders
            }
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

        return lines.allSatisfy { isSafetyLine($0) }
    }

    static func extractFromContentBlocks(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let extracted = extractBlocks(fromArrayCandidate: trimmed) {
            return extracted
        }

        var searchStart = trimmed.startIndex
        while searchStart < trimmed.endIndex {
            guard let openBracket = trimmed[searchStart...].firstIndex(of: "[") else { break }
            if let candidate = balancedArraySubstring(in: trimmed, startingAt: openBracket),
               let extracted = extractBlocks(fromArrayCandidate: candidate) {
                return extracted
            }
            searchStart = trimmed.index(after: openBracket)
        }

        return nil
    }

    private static func stripSafetyHeaderLines(from text: String) -> String {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { !isSafetyLine($0) }
            .joined(separator: "\n")
    }

    private static func extractBlocks(fromArrayCandidate candidate: String) -> String? {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "[",
              trimmed.localizedCaseInsensitiveContains("text"),
              trimmed.localizedCaseInsensitiveContains("type")
        else {
            return nil
        }

        if let data = trimmed.data(using: .utf8),
           let blocks = try? JSONDecoder().decode([ChatStreamContentPart].self, from: data) {
            let joined = ChatStreamContentPart.joinedText(from: blocks)
            if !joined.isEmpty { return joined }
        }

        let regexExtracted = extractTextFields(from: trimmed)
        return regexExtracted.isEmpty ? nil : unescape(regexExtracted)
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

    private static func unescape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\\\", with: "\u{0000}")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\t", with: "\t")
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\'", with: "'")
            .replacingOccurrences(of: "\u{0000}", with: "\\")
    }

    private static func balancedArraySubstring(in text: String, startingAt start: String.Index) -> String? {
        guard text[start] == "[" else { return nil }

        var depth = 0
        var inString = false
        var escape = false
        var stringDelimiter: Character?
        var index = start

        while index < text.endIndex {
            let character = text[index]
            if inString {
                if escape {
                    escape = false
                } else if character == "\\" {
                    escape = true
                } else if character == stringDelimiter {
                    inString = false
                    stringDelimiter = nil
                }
            } else if character == "\"" || character == "'" {
                inString = true
                stringDelimiter = character
            } else if character == "[" {
                depth += 1
            } else if character == "]" {
                depth -= 1
                if depth == 0 {
                    return String(text[start...index])
                }
            }
            index = text.index(after: index)
        }

        return nil
    }
}
