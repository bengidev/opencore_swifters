import Foundation
import Testing

@testable import OpenCore

@Suite("Persistence Conversation History")
struct PersistenceConversationHistoryStoringTests {
    @Test("Preview store returns empty conversations")
    func previewReturnsEmpty() async throws {
        let store = PersistenceConversationHistoryStore.preview
        let conversations = try await store.listConversations()
        #expect(conversations.isEmpty)
    }

    @Test("Preview store returns empty messages")
    func previewReturnsEmptyMessages() async throws {
        let store = PersistenceConversationHistoryStore.preview
        let messages = try await store.loadChatMessages(conversationID: UUID())
        #expect(messages.isEmpty)
    }
}
