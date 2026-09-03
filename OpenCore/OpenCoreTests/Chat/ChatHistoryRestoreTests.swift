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
        ChatClearActiveAtomCommand().execute(on: &state)

        #expect(state.messages.isEmpty)
        #expect(state.streamingRevision == 0)
    }

    @Test("Reopen loads projected history messages")
    func reopenLoadsHistoryMessages() async {
        let conversation = Atom(
            id: UUID(),
            title: "Test",
            createdAt: Date(),
            updatedAt: Date()
        )
        let controller = ChatFlowController(
            history: ChatHistoryClient.testing(
                loadProjectedMessages: { _ in
                    [
                        .text(role: .user, content: "Earlier"),
                        .text(role: .assistant, content: "Reply", isComplete: true)
                    ]
                }
            )
        )

        await controller.reopenAtom(conversation)

        #expect(controller.state.messages.count == 2)
        #expect(controller.state.streamingRevision == 0)
    }

    @Test("Reopen after compaction restores summary instead of full history")
    func reopenAfterCompactionRestoresProjectedThread() async {
        let atomID = UUID()
        let conversation = Atom(
            id: atomID,
            title: "Compacted",
            createdAt: Date(),
            updatedAt: Date()
        )
        let summaryPrefix = AtomSessionContextBuilder.compactionSummaryPrefix
        let controller = ChatFlowController(
            history: ChatHistoryClient.testing(
                loadMessages: { _ in
                    [
                        .text(role: .user, content: "old message"),
                        .text(role: .assistant, content: "recent", isComplete: true)
                    ]
                },
                loadProjectedMessages: { _ in
                    [
                        .text(role: .user, content: summaryPrefix + "merged history</summary>"),
                        .text(role: .assistant, content: "recent", isComplete: true)
                    ]
                }
            )
        )

        await controller.reopenAtom(conversation)

        #expect(controller.state.messages.count == 2)
        guard case let .text(summary) = controller.state.messages[0] else {
            Issue.record("Expected compacted summary message")
            return
        }
        #expect(summary.content.contains("merged history"))
        guard case let .text(recent) = controller.state.messages[1] else {
            Issue.record("Expected recent message")
            return
        }
        #expect(recent.content == "recent")
    }
}
