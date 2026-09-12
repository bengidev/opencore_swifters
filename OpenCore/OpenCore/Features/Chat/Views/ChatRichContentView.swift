import MarkdownUI
import SwiftUI

/// Unified rich renderer for model-authored markdown, LaTeX, and Mermaid.
/// Progressive mode: completed blocks render richly; incomplete fragments stay plain.
struct ChatRichContentView: View {
    let text: String
    var style: ChatRichContentStyle = .assistant
    var isStreaming: Bool = false
    var showsCursor: Bool = false

    @Environment(\.sharedPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        text: String,
        style: ChatRichContentStyle = .assistant,
        isStreaming: Bool = false,
        showsCursor: Bool = false
    ) {
        self.text = text
        self.style = style
        self.isStreaming = isStreaming
        self.showsCursor = showsCursor
    }

    private static let cursorGlyph = "▍"
    private static let cursorBlinkPeriod = 1.1
    private static let cursorMinOpacity = 0.15
    private static let cursorBlinkFade = 1.7

    var body: some View {
        Group {
            if showsCursor, isStreaming, !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    content(cursorOpacity: cursorOpacity(at: timeline.date))
                }
            } else {
                content(cursorOpacity: 1)
            }
        }
        .modifier(ChatRichTextSelectionModifier(enabled: style != .system))
    }

    @ViewBuilder
    private func content(cursorOpacity: Double) -> some View {
        let segments = renderSegments(from: text)
        VStack(alignment: style == .system ? .center : .leading, spacing: 0) {
            ForEach(segments) { renderSegment in
                segmentView(
                    renderSegment.segment,
                    isLast: renderSegment.isLast,
                    cursorOpacity: cursorOpacity
                )
                .id(renderSegment.id)
            }
        }
        .frame(maxWidth: .infinity, alignment: style == .system ? .center : .leading)
    }

    @ViewBuilder
    private func segmentView(
        _ segment: ChatAssistantContentSegment,
        isLast: Bool,
        cursorOpacity: Double
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
            plainTailView(tail, isLast: isLast, cursorOpacity: cursorOpacity)
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
    private func plainTailView(_ tail: String, isLast: Bool, cursorOpacity: Double) -> some View {
        let showCursor = showsCursor && isStreaming && isLast
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            markdownView(ChatAssistantLaTeXPreprocessor.embedInline(tail))

            if showCursor {
                Text(Self.cursorGlyph)
                    .font(palette.swiftUIFont(for: style))
                    .foregroundStyle(palette.accentPrimary.opacity(cursorOpacity))
            }
        }
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
                id: stableSegmentID(index: index, segment: segment),
                segment: segment,
                isLast: index == segments.count - 1
            )
        }
    }

    private func stableSegmentID(index: Int, segment: ChatAssistantContentSegment) -> String {
        switch segment {
        case .markdown(let markdown):
            "markdown-\(index)-\(markdown.hashValue)"
        case .blockLatex(let latex):
            "latex-\(index)-\(latex.hashValue)"
        case .mermaid(let source):
            "mermaid-\(index)-\(source.hashValue)"
        case .plainTail:
            "tail-\(index)"
        }
    }

    private func cursorOpacity(at date: Date) -> Double {
        let phase = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: Self.cursorBlinkPeriod) / Self.cursorBlinkPeriod
        return phase < 0.5
            ? 1 - phase * Self.cursorBlinkFade
            : Self.cursorMinOpacity + (phase - 0.5) * Self.cursorBlinkFade
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
