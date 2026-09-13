import Foundation

/// Stable `ForEach` identity for rich-content segments during streaming.
nonisolated enum ChatRichRenderSegmentID {
    static func id(index: Int, segment: ChatAssistantContentSegment) -> String {
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
}
