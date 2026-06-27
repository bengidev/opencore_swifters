import SwiftUI

struct ChatMessageRowView: View, Equatable {
    let message: ChatMessage
    let isLastAssistantMessage: Bool
    let streamingStatus: ChatStreamingStatus
    let streamErrorMessage: String?

    @Environment(\.sharedPalette) private var palette
    private static let oppositeSpacerMinWidth: CGFloat = 60
    private static let userBubbleCornerRadius: CGFloat = 20
    nonisolated static func == (lhs: ChatMessageRowView, rhs: ChatMessageRowView) -> Bool {
        lhs.message == rhs.message
            && lhs.isLastAssistantMessage == rhs.isLastAssistantMessage
            && lhs.streamingStatus == rhs.streamingStatus
            && lhs.streamErrorMessage == rhs.streamErrorMessage
    }

    var body: some View {
        switch message {
        case let .text(textMessage):
            textRow(textMessage)
        case let .thinking(thinkingMessage):
            assistantSurround {
                ChatReasoningCardView(message: thinkingMessage)
            }
        case let .system(systemMessage):
            Text(systemMessage.content)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func textRow(_ textMessage: ChatTextMessage) -> some View {
        if message.role == .user {
            HStack {
                Spacer(minLength: Self.oppositeSpacerMinWidth)
                Text(textMessage.content)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(palette.controlStrongText)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: Self.userBubbleCornerRadius, style: .continuous)
                            .fill(palette.controlStrong)
                    )
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                assistantTextBody(textMessage)

                if isLastAssistantMessage, let streamErrorMessage, streamingStatus == .failed {
                    Text(streamErrorMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func assistantTextBody(_ textMessage: ChatTextMessage) -> some View {
        Group {
            if !textMessage.isComplete, isLastAssistantMessage, streamingStatus == .running {
                ChatAssistantStreamingTextView(
                    text: textMessage.content,
                    palette: palette
                )
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(0)
            } else {
                ChatAssistantMarkdownTextView(text: textMessage.content)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func assistantSurround<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack {
            content()
            Spacer(minLength: Self.oppositeSpacerMinWidth)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}
