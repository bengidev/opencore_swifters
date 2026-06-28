import Foundation
import SwiftData
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

    @Test("Output stream detailJSON round trips through SwiftData")
    @MainActor
    func outputStreamDetailRoundTrip() async throws {
        let schema = Schema([SidePanelConversationEntity.self, SidePanelMessageEntity.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let store = PersistenceConversationHistoryStore.live(modelContainer: container)

        let conversationID = UUID()
        let conversation = SidePanelConversation(
            id: conversationID,
            title: "Test",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        try await store.saveConversation(conversation)

        let messageID = UUID()
        var detail = ChatOutputStreamDetail(status: .completed, cwd: "/tmp")
        detail.appendOutput("line1\nline2\n")
        detail.exitCode = 0
        detail.durationMs = 500
        let message: ChatMessage = .outputStream(
            id: messageID,
            command: "npm test",
            detail: detail,
            isComplete: true,
            timestamp: Date(timeIntervalSince1970: 1)
        )
        try await store.appendChatMessage(conversationID: conversationID, message: message)

        let loaded = try await store.loadChatMessages(conversationID: conversationID)
        #expect(loaded.count == 1)
        guard case let .outputStream(loadedOutput) = loaded[0] else {
            Issue.record("Expected outputStream message")
            return
        }
        #expect(loadedOutput.id == messageID)
        #expect(loadedOutput.command == "npm test")
        #expect(loadedOutput.detail.status == .completed)
        #expect(loadedOutput.detail.outputTail == "line1\nline2\n")
        #expect(loadedOutput.detail.cwd == "/tmp")
        #expect(loadedOutput.detail.exitCode == 0)
        #expect(loadedOutput.detail.durationMs == 500)
        #expect(loadedOutput.isComplete == true)
    }

    @Test("Corrupt detailJSON derives status from isComplete")
    @MainActor
    func corruptDetailJSONFallback() async throws {
        let schema = Schema([SidePanelConversationEntity.self, SidePanelMessageEntity.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let conversation = SidePanelConversationEntity(
            id: UUID(),
            title: "Test",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        context.insert(conversation)

        let completeEntity = SidePanelMessageEntity(
            id: UUID(),
            kindRaw: ChatMessageKind.outputStream.rawValue,
            role: ChatMessageRole.system.rawValue,
            content: "npm test",
            isComplete: true,
            timestamp: Date(timeIntervalSince1970: 1),
            order: 0,
            detailJSON: "not-valid-json",
            conversation: conversation
        )
        conversation.messages.append(completeEntity)
        context.insert(completeEntity)

        let incompleteEntity = SidePanelMessageEntity(
            id: UUID(),
            kindRaw: ChatMessageKind.outputStream.rawValue,
            role: ChatMessageRole.system.rawValue,
            content: "git status",
            isComplete: false,
            timestamp: Date(timeIntervalSince1970: 2),
            order: 1,
            detailJSON: "{bad",
            conversation: conversation
        )
        conversation.messages.append(incompleteEntity)
        context.insert(incompleteEntity)
        try context.save()

        let store = PersistenceConversationHistoryStore.live(modelContainer: container)
        let loaded = try await store.loadChatMessages(conversationID: conversation.id)
        #expect(loaded.count == 2)

        guard case let .outputStream(completeOutput) = loaded[0],
              case let .outputStream(incompleteOutput) = loaded[1] else {
            Issue.record("Expected outputStream messages")
            return
        }
        #expect(completeOutput.detail.status == .completed)
        #expect(incompleteOutput.detail.status == .running)
    }
}
