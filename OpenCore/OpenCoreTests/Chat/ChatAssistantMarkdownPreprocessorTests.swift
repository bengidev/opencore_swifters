import Foundation
import Testing

@testable import OpenCore

@Suite("Chat Assistant Markdown Preprocessor")
struct ChatAssistantMarkdownPreprocessorTests {
    @Test("Inserts paragraph breaks before inline bold section labels")
    func boldSectionLabels() {
        let raw = "Review the metadata.**Check Context:** If tied to an app, inspect docs."
        let normalized = ChatAssistantMarkdownPreprocessor.normalize(raw)
        #expect(normalized.contains("metadata.\n\n**Check Context:**"))
    }

    @Test("Inserts paragraph breaks before multiple section labels")
    func multipleSectionLabels() {
        let raw = """
        First point.**Security Considerations:** Avoid exposing secrets.**Open Questions:** Does metadata clarify purpose?
        """
        let normalized = ChatAssistantMarkdownPreprocessor.normalize(raw)
        #expect(normalized.contains("point.\n\n**Security Considerations:**"))
        #expect(normalized.contains("secrets.\n\n**Open Questions:**"))
    }

    @Test("Inserts paragraph breaks before em dash section dividers")
    func emDashSections() {
        let raw = "Still unclear?——**Final Thoughts** This file appears to be a screenshot."
        let normalized = ChatAssistantMarkdownPreprocessor.normalize(raw)
        #expect(normalized.contains("unclear?\n\n——**Final Thoughts**"))
    }

    @Test("Inserts paragraph breaks before glued bullet lists")
    func gluedBulletLists() {
        let raw = "Next steps: - Inspect file properties - Check app docs - Review metadata"
        let normalized = ChatAssistantMarkdownPreprocessor.normalize(raw)
        #expect(normalized.contains("steps:\n\n- Inspect"))
        #expect(normalized.contains("properties\n\n- Check"))
    }

    @Test("Leaves fenced code blocks unchanged")
    func preservesCodeFences() {
        let raw = """
        Before**Header:** after
        ```
        let value = 1**Not A Header:**
        ```
        Tail**Another:** end
        """
        let normalized = ChatAssistantMarkdownPreprocessor.normalize(raw)
        #expect(normalized.contains("Before\n\n**Header:** after"))
        #expect(normalized.contains("let value = 1**Not A Header:**"))
        #expect(normalized.contains("Tail\n\n**Another:** end"))
    }

    @Test("Inserts blank line before glued GFM tables")
    func gfmTableSpacing() {
        let raw = """
        Further Reading / Resources
        | Type | Title / Link |
        |------|--------------|
        | Books | Example |
        """
        let normalized = ChatAssistantMarkdownPreprocessor.normalize(raw)
        #expect(normalized.contains("Resources\n\n| Type |"))
    }

    @Test("Rewrites HTML line breaks for markdown cells")
    func htmlLineBreaks() {
        let raw = "| Books | Title <br> subtitle |"
        let normalized = ChatAssistantMarkdownPreprocessor.normalize(raw)
        #expect(normalized.contains("Title  subtitle"))
        #expect(!normalized.contains("<br>"))
    }
}
