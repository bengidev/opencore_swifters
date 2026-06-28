import Foundation
import SwiftData

// MARK: - Placeholder message type

/// Minimal message struct for the session sidebar load API.
struct SidePanelMessage: Equatable, Identifiable, Sendable {
    let id: UUID
    let role: String
    let content: String
    let createdAt: Date
}

// MARK: - Client

/// Session-history facade over `PersistenceConversationHistoryStore`.
struct SidePanelHistoryClient: Sendable {
    var listConversations: @Sendable () async throws -> [SidePanelConversation]
    var loadMessages: @Sendable (_ conversationID: UUID) async throws -> [SidePanelMessage]
    var saveConversation: @Sendable (_ conversation: SidePanelConversation) async throws -> Void
    var appendMessage: @Sendable (_ conversationID: UUID, _ message: SidePanelMessage) async throws -> Void
    var deleteConversation: @Sendable (_ conversationID: UUID) async throws -> Void
    var setPinned: @Sendable (_ conversationID: UUID, _ isPinned: Bool) async throws -> Void
    var renameConversation: @Sendable (_ conversationID: UUID, _ title: String) async throws -> Void
    var setGroup: @Sendable (_ conversationID: UUID, _ groupName: String?) async throws -> Void
    var listGroups: @Sendable () async throws -> [String]

    init(
        listConversations: @escaping @Sendable () async throws -> [SidePanelConversation],
        loadMessages: @escaping @Sendable (UUID) async throws -> [SidePanelMessage],
        saveConversation: @escaping @Sendable (SidePanelConversation) async throws -> Void,
        appendMessage: @escaping @Sendable (UUID, SidePanelMessage) async throws -> Void,
        deleteConversation: @escaping @Sendable (UUID) async throws -> Void,
        setPinned: @escaping @Sendable (UUID, Bool) async throws -> Void,
        renameConversation: @escaping @Sendable (UUID, String) async throws -> Void,
        setGroup: @escaping @Sendable (UUID, String?) async throws -> Void,
        listGroups: @escaping @Sendable () async throws -> [String]
    ) {
        self.listConversations = listConversations
        self.loadMessages = loadMessages
        self.saveConversation = saveConversation
        self.appendMessage = appendMessage
        self.deleteConversation = deleteConversation
        self.setPinned = setPinned
        self.renameConversation = renameConversation
        self.setGroup = setGroup
        self.listGroups = listGroups
    }

    static let preview = SidePanelHistoryClient(
        listConversations: { [] },
        loadMessages: { _ in [] },
        saveConversation: { _ in },
        appendMessage: { _, _ in },
        deleteConversation: { _ in },
        setPinned: { _, _ in },
        renameConversation: { _, _ in },
        setGroup: { _, _ in },
        listGroups: { [] }
    )
}

extension SidePanelHistoryClient {
    @MainActor
    static func live(modelContainer: ModelContainer) -> Self {
        let store = PersistenceConversationHistoryStore.live(modelContainer: modelContainer)
        return Self(
            listConversations: { try await store.listConversations() },
            loadMessages: { @MainActor conversationID in
                let messages = try await store.loadChatMessages(conversationID: conversationID)
                return messages.compactMap(Self.sidePanelMessage(from:))
            },
            saveConversation: { @MainActor conversation in
                try await store.saveConversation(conversation)
            },
            appendMessage: { @MainActor conversationID, message in
                guard let chatMessage = Self.chatMessage(from: message) else { return }
                try await store.appendChatMessage(conversationID: conversationID, message: chatMessage)
            },
            deleteConversation: { try await store.deleteConversation(conversationID: $0) },
            setPinned: { try await store.setPinned(conversationID: $0, isPinned: $1) },
            renameConversation: { try await store.renameConversation(conversationID: $0, title: $1) },
            setGroup: { try await store.setGroup(conversationID: $0, groupName: $1) },
            listGroups: { try await store.listGroups() }
        )
    }

    @MainActor
    private static func sidePanelMessage(from message: ChatMessage) -> SidePanelMessage? {
        switch message {
        case let .text(text):
            return SidePanelMessage(
                id: text.id,
                role: text.role.rawValue,
                content: text.content,
                createdAt: text.timestamp
            )
        case let .system(system):
            return SidePanelMessage(
                id: system.id,
                role: system.role.rawValue,
                content: system.content,
                createdAt: system.timestamp
            )
        case .thinking:
            return nil
        case let .outputStream(outputStream):
            return SidePanelMessage(
                id: outputStream.id,
                role: outputStream.role.rawValue,
                content: outputStream.command,
                createdAt: outputStream.timestamp
            )
        }
    }

    @MainActor
    private static func chatMessage(from message: SidePanelMessage) -> ChatMessage? {
        let role = ChatMessageRole(rawValue: message.role) ?? .user
        return .text(
            id: message.id,
            role: role,
            content: message.content,
            timestamp: message.createdAt
        )
    }
}
