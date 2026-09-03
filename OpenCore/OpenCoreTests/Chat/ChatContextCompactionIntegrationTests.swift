import Foundation
import Testing

@testable import OpenCore

@MainActor
@Suite("Chat Context Compaction Integration")
struct ChatContextCompactionIntegrationTests {
    @Test("send syncs messages when compaction runs")
    func sendSyncsMessagesWhenCompactionRuns() async {
        let preference = InMemoryProviderPreferenceStore(
            preference: ProviderPreference(modelID: "test-model")
        )

        var replacedMessages: [ChatMessage]?
        let history = ChatHistoryClient.testing(
            replaceMessages: { _, messages in
                replacedMessages = messages
            }
        )

        let longContent = String(repeating: "a", count: 400)
        let existingMessages = (0..<6).map { _ in
            ChatMessage.text(role: .user, content: longContent)
        }

        let compaction = SettingsContextCompactionClient(
            compactIfNeeded: { messages, _, _, contextLength in
                let engine = SettingsContextCompactionEngine(
                    summarizer: SettingsFixedCompactionSummarizer(summary: "summary")
                )
                return try await engine.compactIfNeeded(
                    messages: messages,
                    sessionEntries: [],
                    leafEntryID: nil,
                    contextLength: contextLength,
                    preference: SettingsContextCompactionPreference(
                        isEnabled: true,
                        minRecentMessages: 2,
                        reserveTokens: 20
                    )
                )
            },
            compactManually: { messages, _, _, _ in
                .unchanged(messages)
            },
            compactForOverflow: { messages, _, _, _ in
                .unchanged(messages)
            }
        )

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
        let preference = InMemoryProviderPreferenceStore(
            preference: ProviderPreference(modelID: "test-model")
        )

        let compaction = SettingsContextCompactionClient(
            compactIfNeeded: { _, _, _, _ in
                throw SettingsContextCompactionError.missingModel
            },
            compactManually: { messages, _, _, _ in
                .unchanged(messages)
            },
            compactForOverflow: { messages, _, _, _ in
                .unchanged(messages)
            }
        )

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
        let preference = InMemoryProviderPreferenceStore(
            preference: ProviderPreference(modelID: "test-model")
        )

        let history = ChatHistoryClient.testing(
            saveAtom: { _ in throw NSError(domain: "test", code: 1) }
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

private struct SettingsFixedCompactionSummarizer: SettingsContextCompactionSummarizing {
    let summary: String

    func summarize(messages: [ChatMessage]) async throws -> String {
        summary
    }

    func summarize(prompt: String) async throws -> String {
        summary
    }
}
