import Foundation
import SwiftData

/// Persistence boundary for chat history. Delegates to the shared repository.
nonisolated struct ChatHistoryClient: Sendable {
    var loadMessages: @Sendable (_ conversationID: UUID) async throws -> [ChatMessage]
    var saveConversation: @Sendable (_ conversation: SidePanelConversation) async throws -> Void
    var appendMessage: @Sendable (_ conversationID: UUID, _ message: ChatMessage) async throws -> Void
    var replaceMessages: @Sendable (_ conversationID: UUID, _ messages: [ChatMessage]) async throws -> Void

    init(
        loadMessages: @escaping @Sendable (UUID) async throws -> [ChatMessage],
        saveConversation: @escaping @Sendable (SidePanelConversation) async throws -> Void,
        appendMessage: @escaping @Sendable (UUID, ChatMessage) async throws -> Void,
        replaceMessages: @escaping @Sendable (UUID, [ChatMessage]) async throws -> Void
    ) {
        self.loadMessages = loadMessages
        self.saveConversation = saveConversation
        self.appendMessage = appendMessage
        self.replaceMessages = replaceMessages
    }

    static let preview = ChatHistoryClient(
        loadMessages: { _ in [] },
        saveConversation: { _ in },
        appendMessage: { _, _ in },
        replaceMessages: { _, _ in }
    )
}

extension ChatHistoryClient {
    @MainActor
    static func live(modelContainer: ModelContainer) -> Self {
        let store = PersistenceConversationHistoryStore.live(modelContainer: modelContainer)
        return Self(
            loadMessages: { try await store.loadChatMessages(conversationID: $0) },
            saveConversation: { try await store.saveConversation($0) },
            appendMessage: { try await store.appendChatMessage(conversationID: $0, message: $1) },
            replaceMessages: { try await store.replaceChatMessages(conversationID: $0, messages: $1) }
        )
    }
}
