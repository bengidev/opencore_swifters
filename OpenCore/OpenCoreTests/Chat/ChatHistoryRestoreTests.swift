import Foundation
import Testing

@testable import OpenCore

@MainActor
@Suite("Chat History Restore")
struct ChatHistoryRestoreTests {
    @Test("Restored messages replace thread content")
    func restoredMessagesReplaceContent() {
        var state = ChatFlowState()
        ChatMessagesRestoredCommand(messages: [
            .text(role: .user, content: "Hi"),
            .text(role: .assistant, content: "Hello", isComplete: true)
        ]).execute(on: &state)

        #expect(state.messages.count == 2)
    }

    @Test("Clear active conversation resets streaming revision")
    func clearResetsStreamingRevision() {
        var state = ChatFlowState(streamingRevision: 3)
        ChatClearActiveConversationCommand().execute(on: &state)

        #expect(state.messages.isEmpty)
        #expect(state.streamingRevision == 0)
    }

    @Test("Reopen loads history messages")
    func reopenLoadsHistoryMessages() async {
        let conversation = SidePanelConversation(
            id: UUID(),
            title: "Test",
            createdAt: Date(),
            updatedAt: Date()
        )
        let controller = ChatFlowController(
            history: ChatHistoryClient(
                loadMessages: { _ in
                    [
                        .text(role: .user, content: "Earlier"),
                        .text(role: .assistant, content: "Reply", isComplete: true)
                    ]
                },
                saveConversation: { _ in },
                appendMessage: { _, _ in },
                replaceMessages: { _, _ in }
            )
        )

        await controller.reopenConversation(conversation)

        #expect(controller.state.messages.count == 2)
        #expect(controller.state.streamingRevision == 0)
    }
}
