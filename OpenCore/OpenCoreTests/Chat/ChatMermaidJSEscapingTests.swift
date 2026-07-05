import Foundation
import Testing

@testable import OpenCore

@Suite("Chat Mermaid JS Escaping")
struct ChatMermaidJSEscapingTests {
    @Test("Quotes plain diagram source")
    func plainSource() {
        let quoted = ChatMermaidJSEscaping.quotedJavaScriptString("graph TD; A-->B")
        #expect(quoted == "\"graph TD; A-->B\"")
    }

    @Test("Escapes quotes, backslashes, and newlines")
    func specialCharacters() {
        let quoted = ChatMermaidJSEscaping.quotedJavaScriptString("line1\nline2 \"quoted\" \\backslash")
        #expect(quoted.contains("\\n"))
        #expect(quoted.contains("\\\""))
        #expect(quoted.contains("\\\\"))
    }

    @Test("Escapes Unicode line separators")
    func unicodeLineSeparators() {
        let source = "a\u{2028}b\u{2029}c"
        let quoted = ChatMermaidJSEscaping.quotedJavaScriptString(source)
        #expect(quoted.contains("\\u2028"))
        #expect(quoted.contains("\\u2029"))
    }
}

@Suite("Chat Mermaid Bundle Resources")
struct ChatMermaidBundleResourceTests {
    @Test("Mermaid render assets ship in the app bundle")
    func bundleResources() {
        let htmlURL = Bundle.main.url(forResource: "mermaid-render", withExtension: "html", subdirectory: "Mermaid")
            ?? Bundle.main.url(forResource: "mermaid-render", withExtension: "html")
        #expect(htmlURL != nil)

        let bundleDirectory = htmlURL?.deletingLastPathComponent()
        let jsURL = bundleDirectory?.appendingPathComponent("mermaid.min.js")
        #expect(jsURL != nil)
        #expect(FileManager.default.fileExists(atPath: jsURL?.path ?? ""))
    }
}
