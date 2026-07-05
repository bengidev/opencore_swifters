import Foundation
import Testing

@testable import OpenCore

@Suite("Chat Assistant Content Segmenter")
struct ChatAssistantContentSegmenterTests {
    @Test("Display math becomes a dedicated LaTeX segment")
    func displayMathSegment() {
        let raw = """
        Intro

        $$
        \\int_0^1 x^2\\,dx = \\frac{1}{3}
        $$

        Outro
        """
        let segments = ChatAssistantContentSegmenter.segments(from: raw)
        #expect(segments.count == 3)
        if case .blockLatex(let latex) = segments[1] {
            #expect(latex.contains("\\int_0^1"))
        } else {
            Issue.record("Expected block LaTeX segment")
        }
    }

    @Test("Mermaid fence becomes a mermaid segment")
    func mermaidSegment() {
        let raw = """
        Before

        ```mermaid
        flowchart TD
          A-->B
        ```

        After
        """
        let segments = ChatAssistantContentSegmenter.segments(from: raw)
        #expect(segments.contains { if case .mermaid(let body) = $0 { return body.contains("flowchart TD") } else { return false } })
    }

    @Test("Open fence becomes plain tail")
    func openFenceTail() {
        let raw = "Start\n```swift\nlet x = 1"
        let segments = ChatAssistantContentSegmenter.segments(from: raw)
        #expect(segments.last == .plainTail("```swift\nlet x = 1"))
    }

    @Test("Inline math prose is classified")
    func inlineLatexProse() {
        let raw = "Energy is $E = mc^2$ in this line."
        let segments = ChatAssistantContentSegmenter.segments(from: raw)
        #expect(segments.count == 1)
        #expect(segments[0] == .inlineLatexProse(raw))
    }

    @Test("Unclosed inline dollar splits rich prefix from plain tail")
    func unclosedInlineDollar() {
        let raw = "Partial $E = mc"
        let segments = ChatAssistantContentSegmenter.segments(from: raw)
        #expect(segments.count == 2)
        #expect(segments[0] == .markdown("Partial "))
        #expect(segments[1] == .plainTail("$E = mc"))
    }

    @Test("Currency dollar keeps GFM table as markdown")
    func currencyDollarTable() {
        let raw = """
        3. Why ReLU Is So Popular

        | Property | What It Means |
        |----------|---------------|
        | **Speed** | Costs less than $5 per layer |
        """
        let segments = ChatAssistantContentSegmenter.segments(from: raw)
        #expect(segments.count == 1)
        guard case .markdown(let markdown) = segments[0] else {
            Issue.record("Expected markdown segment")
            return
        }
        #expect(markdown.contains("| Property |"))
        #expect(markdown.contains("**Speed**"))
    }

    @Test("Unclosed backtick only plain-tails from the delimiter")
    func unclosedBacktickSplit() {
        let raw = "Use `relu` for speed and `part"
        let segments = ChatAssistantContentSegmenter.segments(from: raw)
        #expect(segments.count == 2)
        #expect(segments[0] == .markdown("Use `relu` for speed and "))
        #expect(segments[1] == .plainTail("`part"))
    }

    @Test("Completed messages render tables as markdown")
    func completedMessageTable() {
        let raw = """
        Further Reading / Resources
        | Type | Title / Link |
        |------|--------------|
        | Books | "Deep Learning with Python" (François Chollet) – ch. 8 <br> "Transformers" |
        """
        let segments = ChatAssistantContentSegmenter.segments(from: raw, progressive: false)
        #expect(segments.count == 1)
        guard case .markdown(let markdown) = segments[0] else {
            Issue.record("Expected markdown segment")
            return
        }
        #expect(markdown.contains("| Type |"))
        #expect(markdown.contains("| Books |"))
    }

    @Test("Completed messages ignore unclosed inline delimiters")
    func completedMessageIgnoresUnclosedDelimiter() {
        let raw = "Partial $E = mc"
        let segments = ChatAssistantContentSegmenter.segments(from: raw, progressive: false)
        #expect(segments.count == 1)
        #expect(segments[0] == .markdown(raw))
    }
}
