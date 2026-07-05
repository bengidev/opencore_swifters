import Foundation
import Testing

@testable import OpenCore

@Suite("Chat Assistant LaTeX Preprocessor")
struct ChatAssistantLaTeXPreprocessorTests {
    @Test("Inline dollars become image markdown")
    func inlineEmbed() {
        let raw = "See $x^2$ here."
        let embedded = ChatAssistantLaTeXPreprocessor.embedInline(raw)
        #expect(embedded.contains("opencore-latex://"))
        #expect(embedded.contains("![latex]"))
    }

    @Test("Decode round trip")
    func decode() throws {
        let url = try #require(URL(string: "opencore-latex://x%5E2"))
        let decoded = ChatAssistantLaTeXPreprocessor.decodeLatex(from: url)
        #expect(decoded?.latex == "x^2")
        #expect(decoded?.isBlock == false)
    }
}
