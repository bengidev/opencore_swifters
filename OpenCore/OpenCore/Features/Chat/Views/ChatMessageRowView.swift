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
            ChatRichContentView(text: systemMessage.content, style: .system)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
        case let .outputStream(outputStreamMessage):
            assistantSurround {
                ChatOutputStreamCardView(message: outputStreamMessage)
            }
        }
    }

    @ViewBuilder
    private func textRow(_ textMessage: ChatTextMessage) -> some View {
        if message.role == .user {
            ChatUserMessageBubbleView(textMessage: textMessage)
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
        ChatRichContentView(
            text: textMessage.content,
            isStreaming: isAssistantTextStreaming(textMessage)
        )
        .fixedSize(horizontal: false, vertical: true)
        .layoutPriority(0)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func isAssistantTextStreaming(_ textMessage: ChatTextMessage) -> Bool {
        !textMessage.isComplete && isLastAssistantMessage && streamingStatus == .running
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
