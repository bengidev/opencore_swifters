import MarkdownUI
import SwiftUI

/// Unified rich renderer for model-authored markdown, LaTeX, and Mermaid.
/// Progressive mode: completed blocks render richly; incomplete fragments stay plain.
struct ChatRichContentView: View {
    let text: String
    var style: ChatRichContentStyle = .assistant
    var isStreaming: Bool = false

    @Environment(\.sharedPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        text: String,
        style: ChatRichContentStyle = .assistant,
        isStreaming: Bool = false
    ) {
        self.text = text
        self.style = style
        self.isStreaming = isStreaming
    }

    var body: some View {
        content
            .modifier(ChatRichTextSelectionModifier(enabled: style != .system))
    }

    @ViewBuilder
    private var content: some View {
        let segments = renderSegments(from: text)
        VStack(alignment: style == .system ? .center : .leading, spacing: 0) {
            ForEach(segments) { renderSegment in
                segmentView(
                    renderSegment.segment,
                    isLast: renderSegment.isLast
                )
                .id(renderSegment.id)
            }
        }
        .frame(maxWidth: .infinity, alignment: style == .system ? .center : .leading)
    }

    @ViewBuilder
    private func segmentView(
        _ segment: ChatAssistantContentSegment,
        isLast: Bool
    ) -> some View {
        switch segment {
        case .markdown(let markdown):
            markdownView(ChatAssistantLaTeXPreprocessor.embedInline(markdown))
        case .blockLatex(let latex):
            ChatBlockLaTeXView(
                latex: latex,
                uiFont: palette.uiFont(for: style),
                textColor: palette.textSecondary
            )
        case .mermaid(let source):
            ChatMermaidSnapshotView(source: source, palette: palette)
        case .plainTail(let tail):
            plainTailView(tail)
                .contentTransition(isStreaming && isLast && !reduceMotion ? .interpolate : .identity)
        }
    }

    @ViewBuilder
    private func markdownView(_ markdown: String) -> some View {
        Markdown(MarkdownContent(markdown))
            .markdownTheme(palette.richContentTheme(style: style))
            .markdownImageProvider(
                ChatAssistantMarkdownLaTeXImageProvider(
                    uiFont: palette.uiFont(for: style),
                    textColor: palette.textSecondary
                )
            )
            .markdownInlineImageProvider(
                ChatAssistantMarkdownLaTeXInlineImageProvider(uiFont: palette.uiFont(for: style))
            )
            .environment(\.openURL, openURLAction)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func plainTailView(_ tail: String) -> some View {
        markdownView(ChatAssistantLaTeXPreprocessor.embedInline(tail))
            .frame(maxWidth: .infinity, alignment: style == .system ? .center : .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var openURLAction: OpenURLAction {
        OpenURLAction { url in
            guard ChatAssistantMarkdownLinkPolicy.isAllowed(url) else {
                return .discarded
            }
            return .systemAction(url)
        }
    }

    private func renderSegments(from value: String) -> [ChatRichRenderSegment] {
        let normalized = ChatAssistantMarkdownPreprocessor.normalize(value)
        let segments = ChatAssistantContentSegmenter.segments(from: normalized, progressive: isStreaming)
        return segments.enumerated().map { index, segment in
            ChatRichRenderSegment(
                id: ChatRichRenderSegmentID.id(index: index, segment: segment),
                segment: segment,
                isLast: index == segments.count - 1
            )
        }
    }
}

private struct ChatRichRenderSegment: Identifiable {
    let id: String
    let segment: ChatAssistantContentSegment
    let isLast: Bool
}

private struct ChatRichTextSelectionModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.textSelection(.enabled)
        } else {
            content.textSelection(.disabled)
        }
    }
}
