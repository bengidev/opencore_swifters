import Foundation
import Testing

@testable import OpenCore

@MainActor
@Suite("Chat Context Compaction Integration")
struct ChatContextCompactionIntegrationTests {
    @Test("send replaces messages when compaction runs")
    func sendReplacesMessagesWhenCompactionRuns() async {
        let preference = SidePanelInMemoryProviderPreferenceStore(
            preference: SidePanelProviderPreference(modelID: "test-model")
        )

        var replacedMessages: [ChatMessage]?
        let history = ChatHistoryClient(
            loadMessages: { _ in [] },
            saveConversation: { _ in },
            appendMessage: { _, _ in },
            replaceMessages: { _, messages in
                replacedMessages = messages
            }
        )

        let longContent = String(repeating: "a", count: 400)
        let existingMessages = (0..<6).map { _ in
            ChatMessage.text(role: .user, content: longContent)
        }

        let compaction = SettingsContextCompactionClient { messages, contextLength in
            let engine = SettingsContextCompactionEngine()
            return try await engine.compactIfNeeded(
                messages: messages,
                contextLength: contextLength,
                preference: SettingsContextCompactionPreference(
                    isEnabled: true,
                    triggerThresholdPercent: 10,
                    minRecentMessages: 2
                )
            )
        }

        let chat = ChatFlowController(
            state: ChatFlowState(
                messages: existingMessages,
                draftMessage: "hello"
            ),
            streaming: ChatStreamingClient(stream: { _ in AsyncStream { $0.finish() } }),
            history: history,
            providerPreference: preference,
            contextCompaction: compaction,
            contextLengthResolver: { 100 }
        )

        await chat.sendMessage()

        #expect(chat.state.messages.count < existingMessages.count + 1)
        #expect(replacedMessages != nil)
    }

    @Test("compaction failure aborts send and restores draft")
    func compactionFailureAbortsSend() async {
        let preference = SidePanelInMemoryProviderPreferenceStore(
            preference: SidePanelProviderPreference(modelID: "test-model")
        )

        let compaction = SettingsContextCompactionClient { _, _ in
            throw SettingsContextCompactionError.missingModel
        }

        let chat = ChatFlowController(
            state: ChatFlowState(
                messages: [],
                draftMessage: "hello"
            ),
            streaming: ChatStreamingClient(stream: { _ in AsyncStream { $0.finish() } }),
            providerPreference: preference,
            contextCompaction: compaction,
            contextLengthResolver: { 100 }
        )

        await chat.sendMessage()

        #expect(chat.state.streamingStatus == .failed)
        #expect(chat.state.streamErrorMessage == "Could not prepare conversation for sending.")
        #expect(chat.state.messages.isEmpty)
        #expect(chat.state.draftMessage == "hello")
        #expect(chat.state.isSending == false)
    }

    @Test("persistence failure aborts send and restores draft")
    func persistenceFailureAbortsSend() async {
        let preference = SidePanelInMemoryProviderPreferenceStore(
            preference: SidePanelProviderPreference(modelID: "test-model")
        )

        let history = ChatHistoryClient(
            loadMessages: { _ in [] },
            saveConversation: { _ in throw NSError(domain: "test", code: 1) },
            appendMessage: { _, _ in },
            replaceMessages: { _, _ in }
        )

        let chat = ChatFlowController(
            state: ChatFlowState(
                messages: [],
                draftMessage: "hello"
            ),
            streaming: ChatStreamingClient(stream: { _ in AsyncStream { $0.finish() } }),
            history: history,
            providerPreference: preference,
            contextLengthResolver: { 0 }
        )

        await chat.sendMessage()

        #expect(chat.state.streamingStatus == .failed)
        #expect(chat.state.messages.isEmpty)
        #expect(chat.state.draftMessage == "hello")
    }
}
