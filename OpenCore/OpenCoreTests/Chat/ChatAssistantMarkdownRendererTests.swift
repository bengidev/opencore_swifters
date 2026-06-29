import Foundation
import SwiftUI
import Testing
import UIKit

@testable import OpenCore

@Suite("Chat Assistant Markdown Renderer")
@MainActor
struct ChatAssistantMarkdownRendererTests {
    private let palette = SharedOpenCorePalette.resolve(.light)

    @Test("Inline code uses monospaced secondary styling")
    func inlineCode() {
        let rendered = ChatAssistantMarkdownRenderer.nsAttributedString(
            from: "Use `foo` here.",
            palette: palette
        )
        let range = (rendered.string as NSString).range(of: "foo")
        #expect(range.location != NSNotFound)

        let font = rendered.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont
        #expect(font != nil)
        #expect(font?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) == true)
        #expect(font?.pointSize == 16)

        let color = rendered.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? UIColor
        #expect(colorsMatch(color, UIColor(palette.textSecondary)))
    }

    @Test("Strong text uses semibold weight")
    func strongText() {
        let rendered = ChatAssistantMarkdownRenderer.nsAttributedString(
            from: "**Important** note.",
            palette: palette
        )
        let range = (rendered.string as NSString).range(of: "Important")
        #expect(range.location != NSNotFound)

        let font = rendered.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont
        #expect(font != nil)
        #expect(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
        #expect(font?.pointSize == 16)
    }

    @Test("Plain prose keeps body styling")
    func plainProse() {
        let markdown = "GeForce is NVIDIA's brand for consumer GPUs."
        let rendered = ChatAssistantMarkdownRenderer.nsAttributedString(from: markdown, palette: palette)
        #expect(rendered.string == markdown)

        let font = rendered.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        #expect(font?.pointSize == 16)
        #expect(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == false)
        #expect(font?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) == false)

        let color = rendered.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        #expect(colorsMatch(color, UIColor(palette.textPrimary)))
    }

    @Test("Unclosed inline backtick falls back to plain body")
    func unclosedBacktickFallback() {
        let markdown = "Streaming `partial token"
        let rendered = ChatAssistantMarkdownRenderer.nsAttributedString(from: markdown, palette: palette)
        #expect(rendered.string == markdown)

        let font = rendered.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        #expect(font?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) == false)
        #expect(font?.pointSize == 16)
    }

    @Test("Fenced code block uses monospaced block styling")
    func fencedCodeBlock() {
        let markdown = """
        Before

        ```
        let x = 1
        ```

        After
        """
        let rendered = ChatAssistantMarkdownRenderer.nsAttributedString(from: markdown, palette: palette)
        let range = (rendered.string as NSString).range(of: "let x = 1")
        #expect(range.location != NSNotFound)

        let font = rendered.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont
        #expect(font?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) == true)
        #expect(font?.pointSize == 12)

        let color = rendered.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? UIColor
        #expect(colorsMatch(color, UIColor(palette.textSecondary)))

        let background = rendered.attribute(.backgroundColor, at: range.location, effectiveRange: nil) as? UIColor
        #expect(colorsMatch(background, UIColor(palette.surfaceSubtle)))
    }

    @Test("Strong inline code keeps monospaced semibold styling")
    func strongInlineCode() {
        let rendered = ChatAssistantMarkdownRenderer.nsAttributedString(
            from: "**`token`**",
            palette: palette
        )
        let range = (rendered.string as NSString).range(of: "token")
        #expect(range.location != NSNotFound)

        let font = rendered.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont
        #expect(font != nil)
        #expect(font?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) == true)
        #expect(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
    }

    @Test("Section labels render as separate paragraphs")
    func sectionLabelParagraphs() {
        let markdown = "Review metadata.**Check Context:** Inspect app docs."
        let rendered = ChatAssistantMarkdownRenderer.nsAttributedString(from: markdown, palette: palette)
        let string = rendered.string as NSString
        let contextRange = string.range(of: "Check Context:")
        #expect(contextRange.location != NSNotFound)

        let style = rendered.attribute(.paragraphStyle, at: contextRange.location, effectiveRange: nil) as? NSParagraphStyle
        #expect(style != nil)
        #expect((style?.paragraphSpacingBefore ?? 0) >= 0)
    }

    @Test("Disallowed link schemes are not linked")
    func blockedLinkSchemes() {
        let rendered = ChatAssistantMarkdownRenderer.nsAttributedString(
            from: "[bad](javascript:alert(1)) and [ok](https://example.com)",
            palette: palette
        )
        let badRange = (rendered.string as NSString).range(of: "bad")
        let okRange = (rendered.string as NSString).range(of: "ok")
        #expect(badRange.location != NSNotFound)
        #expect(okRange.location != NSNotFound)

        #expect(rendered.attribute(.link, at: badRange.location, effectiveRange: nil) == nil)
        #expect(rendered.attribute(.link, at: okRange.location, effectiveRange: nil) != nil)
    }

    private func colorsMatch(_ lhs: UIColor?, _ rhs: UIColor) -> Bool {
        guard let lhs else { return false }
        var lR: CGFloat = 0
        var lG: CGFloat = 0
        var lB: CGFloat = 0
        var lA: CGFloat = 0
        var rR: CGFloat = 0
        var rG: CGFloat = 0
        var rB: CGFloat = 0
        var rA: CGFloat = 0
        lhs.getRed(&lR, green: &lG, blue: &lB, alpha: &lA)
        rhs.getRed(&rR, green: &rG, blue: &rB, alpha: &rA)
        let epsilon: CGFloat = 0.02
        return abs(lR - rR) < epsilon
            && abs(lG - rG) < epsilon
            && abs(lB - rB) < epsilon
            && abs(lA - rA) < epsilon
    }
}
