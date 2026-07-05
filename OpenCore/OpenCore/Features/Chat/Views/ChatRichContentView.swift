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
    @State private var displayedText = ""
    @State private var updateTask: Task<Void, Never>?

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
        .onAppear { displayedText = text }
        .onChange(of: text) { _, newValue in
            scheduleUpdate(newValue)
        }
        .onChange(of: isStreaming) { _, streaming in
            guard !streaming else { return }
            updateTask?.cancel()
            displayedText = text
        }
        .modifier(ChatRichTextSelectionModifier(enabled: style != .system))
    }

    @ViewBuilder
    private func content(cursorOpacity: Double) -> some View {
        let segments = preparedSegments(from: displayedText)
        VStack(alignment: style == .system ? .center : .leading, spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                segmentView(segment, isLast: index == segments.count - 1, cursorOpacity: cursorOpacity)
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
        case .inlineLatexProse(let prose):
            ChatInlineLaTeXView(
                latex: prose,
                uiFont: palette.uiFont(for: style),
                textColor: palette.textSecondary
            )
        case .plainTail(let tail):
            plainTailView(tail, isLast: isLast, cursorOpacity: cursorOpacity)
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
        let color = plainTextColor
        (
            Text(tail)
                .font(palette.swiftUIFont(for: style))
                .foregroundStyle(color)
            + Text(showCursor ? Self.cursorGlyph : "")
                .font(palette.swiftUIFont(for: style))
                .foregroundStyle(palette.accentPrimary.opacity(cursorOpacity))
        )
        .frame(maxWidth: .infinity, alignment: style == .system ? .center : .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var plainTextColor: Color {
        switch style {
        case .assistant:
            palette.textPrimary
        case .reasoning, .terminal, .system:
            palette.textSecondary
        }
    }

    private var openURLAction: OpenURLAction {
        OpenURLAction { url in
            guard ChatAssistantMarkdownLinkPolicy.isAllowed(url) else {
                return .discarded
            }
            return .systemAction(url)
        }
    }

    private func preparedSegments(from value: String) -> [ChatAssistantContentSegment] {
        let normalized = ChatAssistantMarkdownPreprocessor.normalize(value)
        return ChatAssistantContentSegmenter.segments(from: normalized, progressive: isStreaming)
    }

    private func scheduleUpdate(_ newValue: String) {
        guard isStreaming else {
            displayedText = newValue
            return
        }
        updateTask?.cancel()
        updateTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 33_000_000)
            guard !Task.isCancelled else { return }
            displayedText = newValue
            updateTask = nil
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
