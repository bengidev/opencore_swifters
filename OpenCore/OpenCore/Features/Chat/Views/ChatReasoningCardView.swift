import SwiftUI

extension Notification.Name {
    /// Posted when a streaming reasoning card collapses so the thread can re-anchor scroll.
    static let chatThreadRequestScrollToBottom = Notification.Name("OpenCore.chatThreadRequestScrollToBottom")
}

/// Collapsible reasoning card — streams monospace text while the model thinks.
struct ChatReasoningCardView: View {
    let content: String
    let isComplete: Bool
    let isStreaming: Bool
    var collapseForDownstreamStream: Bool = false

    @Environment(\.sharedPalette) private var palette

    /// Expands while thinking streams; auto-collapses before answer or tool output appears.
    @State private var isExpanded: Bool
    @State private var didAutoCollapse = false

    init(
        content: String,
        isComplete: Bool,
        isStreaming: Bool,
        collapseForDownstreamStream: Bool = false
    ) {
        self.content = content
        self.isComplete = isComplete
        self.isStreaming = isStreaming
        self.collapseForDownstreamStream = collapseForDownstreamStream
        _isExpanded = State(initialValue: isStreaming && !collapseForDownstreamStream)
    }

    var body: some View {
        Button {
            guard showsStreamingBody else { return }
            withAnimation(.easeInOut(duration: 0.22)) {
                isExpanded.toggle()
            }
        } label: {
            ChatMessageCardChrome {
                VStack(alignment: .leading, spacing: 8) {
                    header

                    if showsStreamingBody {
                        streamingBody
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!showsStreamingBody)
        .animation(.easeInOut(duration: 0.22), value: isExpanded)
        .onChange(of: isStreaming) { _, streaming in
            guard !streaming else { return }
            autoCollapseIfNeeded()
        }
        .onChange(of: collapseForDownstreamStream) { _, shouldCollapse in
            guard shouldCollapse else { return }
            autoCollapseIfNeeded()
        }
    }

    private func autoCollapseIfNeeded() {
        guard !didAutoCollapse, isExpanded else { return }
        didAutoCollapse = true
        withAnimation(.easeInOut(duration: 0.22)) {
            isExpanded = false
        }
        NotificationCenter.default.post(name: .chatThreadRequestScrollToBottom, object: nil)
    }

    private var showsStreamingBody: Bool {
        isStreaming || !content.isEmpty
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.accentPrimary)
                .accessibilityHidden(true)

            Text(isComplete ? "Thought" : "Thinking")
                .font(SharedOpenCoreTypography.monoSM)
                .foregroundStyle(palette.textSecondary)
                .monoTracking()

            if isStreaming {
                ChatStreamingPulseDot()
            }

            Spacer(minLength: 8)

            if showsStreamingBody {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
        }
    }

    @ViewBuilder
    private var streamingBody: some View {
        if isExpanded {
            ChatRichContentView(
                text: displayedContent,
                style: .reasoning,
                isStreaming: isStreaming,
                showsCursor: isStreaming
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
            .accessibilityLabel(displayedContent)
        }
    }

    private var displayedContent: String {
        if !content.isEmpty {
            return content
        }
        return isStreaming ? "…" : ""
    }
}

extension ChatReasoningCardView {
    init(message: ChatThinkingMessage, collapseForDownstreamStream: Bool = false) {
        self.init(
            content: message.content,
            isComplete: message.isComplete,
            isStreaming: !message.isComplete,
            collapseForDownstreamStream: collapseForDownstreamStream
        )
    }
}

