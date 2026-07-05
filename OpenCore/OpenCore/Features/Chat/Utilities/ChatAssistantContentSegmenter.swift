import Foundation

/// Splits normalized assistant text into progressively renderable segments.
nonisolated enum ChatAssistantContentSegmenter: Sendable {
    private static let blockPatterns = [
        #"\$\$([\s\S]+?)\$\$"#,
        #"\\\[([\s\S]+?)\\\]"#,
    ]

    static func segments(from markdown: String, progressive: Bool = true) -> [ChatAssistantContentSegment] {
        guard !markdown.isEmpty else { return [] }

        let fenceParts = markdown.components(separatedBy: "```")
        let fenceCount = fenceParts.count - 1

        if fenceCount % 2 != 0 {
            let completeCount = fenceParts.count - 1
            var output: [ChatAssistantContentSegment] = []
            for index in 0..<completeCount {
                appendFencePart(fenceParts[index], index: index, progressive: progressive, to: &output)
            }
            let unclosed = fenceParts[completeCount]
            if progressive {
                output.append(.plainTail("```" + unclosed))
            } else {
                appendUnclosedFenceTail(unclosed, to: &output)
            }
            return output
        }

        var output: [ChatAssistantContentSegment] = []
        for (index, part) in fenceParts.enumerated() {
            appendFencePart(part, index: index, progressive: progressive, to: &output)
        }
        return output
    }

    private static func appendUnclosedFenceTail(
        _ unclosed: String,
        to output: inout [ChatAssistantContentSegment]
    ) {
        if let tableStart = unclosed.range(of: "\n|") {
            let codeBody = String(unclosed[..<tableStart.lowerBound])
            let tableBody = String(unclosed[tableStart.lowerBound...])
                .trimmingCharacters(in: .newlines)
            if !codeBody.isEmpty {
                output.append(.markdown(wrapCodeFence(codeBody)))
            }
            if !tableBody.isEmpty {
                output.append(contentsOf: splitProse(tableBody, progressive: false))
            }
            return
        }

        output.append(.markdown(wrapCodeFence(unclosed)))
    }

    private static func appendFencePart(
        _ part: String,
        index: Int,
        progressive: Bool,
        to output: inout [ChatAssistantContentSegment]
    ) {
        if index.isMultiple(of: 2) {
            output.append(contentsOf: splitProse(part, progressive: progressive))
        } else if let mermaid = mermaidBody(from: part) {
            output.append(.mermaid(mermaid))
        } else {
            output.append(.markdown(wrapCodeFence(part)))
        }
    }

    private static func mermaidBody(from fenced: String) -> String? {
        let trimmed = fenced.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("mermaid") else { return nil }
        let body = trimmed.dropFirst("mermaid".count).trimmingCharacters(in: .whitespacesAndNewlines)
        return body.isEmpty ? nil : body
    }

    private static func wrapCodeFence(_ inner: String) -> String {
        "```" + inner + "```"
    }

    private static func splitProse(_ prose: String, progressive: Bool) -> [ChatAssistantContentSegment] {
        guard !prose.isEmpty else { return [] }

        var remaining = prose
        var output: [ChatAssistantContentSegment] = []

        while !remaining.isEmpty {
            if let match = firstBlockMatch(in: remaining) {
                let prefix = String(remaining[..<match.range.lowerBound])
                if !prefix.isEmpty {
                    output.append(contentsOf: splitMarkdownProse(prefix, progressive: progressive))
                }
                output.append(.blockLatex(match.latex))
                remaining = String(remaining[match.range.upperBound...])
            } else {
                output.append(contentsOf: splitMarkdownProse(remaining, progressive: progressive))
                break
            }
        }

        return output
    }

    private static func splitMarkdownProse(_ prose: String, progressive: Bool) -> [ChatAssistantContentSegment] {
        guard !prose.isEmpty else { return [] }

        if progressive, let delimiterStart = earliestIncompleteDelimiter(in: prose) {
            let prefix = String(prose[..<delimiterStart])
            let tail = String(prose[delimiterStart...])
            var output: [ChatAssistantContentSegment] = []
            if !prefix.isEmpty {
                output.append(contentsOf: splitMarkdownProse(prefix, progressive: progressive))
            }
            if !tail.isEmpty {
                output.append(contentsOf: segmentsFromProgressiveTail(tail))
            }
            return output
        }

        return [classifyResolvedMarkdownProse(prose)]
    }

    /// Pulls complete markdown blocks out of a progressive tail so tables and headings
    /// render richly even when an earlier delimiter is still incomplete.
    private static func segmentsFromProgressiveTail(_ tail: String) -> [ChatAssistantContentSegment] {
        let lines = tail.components(separatedBy: "\n")
        var output: [ChatAssistantContentSegment] = []
        var plainLines: [String] = []
        var index = 0

        func flushPlainLines() {
            guard !plainLines.isEmpty else { return }
            output.append(.plainTail(plainLines.joined(separator: "\n")))
            plainLines = []
        }

        while index < lines.count {
            if isGFMTableHeader(lines[index]),
               index + 1 < lines.count,
               isGFMTableSeparator(lines[index + 1]) {
                flushPlainLines()
                var tableLines = [lines[index], lines[index + 1]]
                index += 2
                while index < lines.count, isGFMTableRow(lines[index]) {
                    tableLines.append(lines[index])
                    index += 1
                }
                output.append(.markdown(markdownTableBlock(from: tableLines)))
            } else if isMarkdownHeadingLine(lines[index]) || isThematicBreakLine(lines[index]) {
                flushPlainLines()
                output.append(.markdown(lines[index]))
                index += 1
            } else {
                plainLines.append(lines[index])
                index += 1
            }
        }

        flushPlainLines()
        return output
    }

    private static func markdownTableBlock(from lines: [String]) -> String {
        "\n\n" + lines.joined(separator: "\n")
    }

    private static func isGFMTableRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("|"), trimmed.hasSuffix("|"), trimmed.count > 2 else { return false }
        return true
    }

    private static func isGFMTableHeader(_ line: String) -> Bool {
        isGFMTableRow(line)
    }

    private static func isGFMTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("|"), trimmed.hasSuffix("|") else { return false }
        let inner = trimmed.dropFirst().dropLast()
        guard !inner.isEmpty else { return false }
        return inner.allSatisfy { $0 == "|" || $0 == "-" || $0 == ":" || $0 == " " }
    }

    private static func isMarkdownHeadingLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return false }
        return trimmed.range(of: #"^#{1,6}\s+\S"#, options: .regularExpression) != nil
    }

    private static func isThematicBreakLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return trimmed.allSatisfy { $0 == "-" || $0 == " " || $0 == "*" || $0 == "_" }
            && trimmed.contains("-")
    }

    private static func classifyResolvedMarkdownProse(_ prose: String) -> ChatAssistantContentSegment {
        if hasInlineLatex(prose) {
            return .inlineLatexProse(prose)
        }
        return .markdown(prose)
    }

    private static func earliestIncompleteDelimiter(in text: String) -> String.Index? {
        let candidates = [
            incompleteBacktickStart(in: text),
            incompleteDisplayMathStart(in: text),
            incompleteInlineLatexStart(in: text),
            incompleteParenLatexStart(in: text),
        ].compactMap { $0 }

        return candidates.min()
    }

    private static func incompleteBacktickStart(in text: String) -> String.Index? {
        var inCode = false
        var openIndex: String.Index?
        var index = text.startIndex

        while index < text.endIndex {
            if text[index] == "`" {
                if inCode {
                    inCode = false
                    openIndex = nil
                } else {
                    inCode = true
                    openIndex = index
                }
            }
            index = text.index(after: index)
        }

        return inCode ? openIndex : nil
    }

    private static func incompleteDisplayMathStart(in text: String) -> String.Index? {
        var index = text.startIndex

        while index < text.endIndex {
            guard text[index] == "$" else {
                index = text.index(after: index)
                continue
            }

            let next = text.index(after: index)
            guard next < text.endIndex, text[next] == "$" else {
                index = text.index(after: index)
                continue
            }

            let openStart = index
            let searchStart = text.index(next, offsetBy: 1)
            guard searchStart < text.endIndex else { return openStart }

            if let closeRange = text.range(of: "$$", range: searchStart..<text.endIndex) {
                index = closeRange.upperBound
                continue
            }

            return openStart
        }

        return nil
    }

    private static func incompleteInlineLatexStart(in text: String) -> String.Index? {
        var inMath = false
        var openIndex: String.Index?
        var index = text.startIndex

        while index < text.endIndex {
            guard text[index] == "$" else {
                index = text.index(after: index)
                continue
            }

            let next = text.index(after: index)
            if next < text.endIndex, text[next] == "$" {
                index = skipDisplayMath(from: index, in: text) ?? text.endIndex
                continue
            }

            if isCurrencyDollar(in: text, at: index) {
                index = text.index(after: index)
                continue
            }

            if inMath {
                inMath = false
                openIndex = nil
            } else {
                inMath = true
                openIndex = index
            }
            index = text.index(after: index)
        }

        return inMath ? openIndex : nil
    }

    private static func skipDisplayMath(from openIndex: String.Index, in text: String) -> String.Index? {
        let searchStart = text.index(openIndex, offsetBy: 2)
        guard searchStart <= text.endIndex else { return nil }
        if searchStart == text.endIndex {
            return searchStart
        }
        if let closeRange = text.range(of: "$$", range: searchStart..<text.endIndex) {
            return closeRange.upperBound
        }
        return text.endIndex
    }

    private static func isCurrencyDollar(in text: String, at index: String.Index) -> Bool {
        guard text[index] == "$" else { return false }

        var cursor = text.index(after: index)
        if cursor < text.endIndex, text[cursor] == " " {
            cursor = text.index(after: cursor)
        }
        guard cursor < text.endIndex else { return false }
        return text[cursor].isNumber
    }

    private static func incompleteParenLatexStart(in text: String) -> String.Index? {
        guard let openRegex = try? NSRegularExpression(pattern: #"\\\("#),
              let closeRegex = try? NSRegularExpression(pattern: #"\\\)"#) else {
            return nil
        }

        let nsRange = NSRange(text.startIndex..., in: text)
        let opens = openRegex.matches(in: text, range: nsRange).compactMap { Range($0.range, in: text)?.lowerBound }
        let closes = closeRegex.matches(in: text, range: nsRange).compactMap { Range($0.range, in: text)?.lowerBound }

        var closeIterator = closes.makeIterator()
        var nextClose = closeIterator.next()

        for open in opens {
            while let close = nextClose, close < open {
                nextClose = closeIterator.next()
            }

            if let close = nextClose, close > open {
                nextClose = closeIterator.next()
            } else {
                return open
            }
        }

        return nil
    }

    private static func firstBlockMatch(in text: String) -> (latex: String, range: Range<String.Index>)? {
        for pattern in blockPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let swiftRange = Range(match.range, in: text),
                  match.numberOfRanges > 1,
                  let latexRange = Range(match.range(at: 1), in: text) else {
                continue
            }
            return (String(text[latexRange]), swiftRange)
        }
        return nil
    }

    private static func hasInlineLatex(_ text: String) -> Bool {
        if let regex = try? NSRegularExpression(pattern: #"\\\((.+?)\\\)"#),
           regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
            return true
        }
        if let regex = try? NSRegularExpression(pattern: #"(?<!\$)\$(?!\$)([^\n$]+?)(?<!\$)\$(?!\$)"#),
           regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
            return true
        }
        return false
    }
}
