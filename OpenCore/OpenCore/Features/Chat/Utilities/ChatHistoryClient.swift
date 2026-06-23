import Foundation
import SwiftData

/// Persistence boundary for chat history. Pure domain types cross this API;
/// SwiftData entities never leak past it.
nonisolated struct ChatHistoryClient: Sendable {
    var loadMessages: @Sendable (_ conversationID: UUID) async throws -> [ChatMessage]
    var saveConversation: @Sendable (_ conversation: SidePanelConversation) async throws -> Void
    var appendMessage: @Sendable (_ conversationID: UUID, _ message: ChatMessage) async throws -> Void

    init(
        loadMessages: @escaping @Sendable (UUID) async throws -> [ChatMessage],
        saveConversation: @escaping @Sendable (SidePanelConversation) async throws -> Void,
        appendMessage: @escaping @Sendable (UUID, ChatMessage) async throws -> Void
    ) {
        self.loadMessages = loadMessages
        self.saveConversation = saveConversation
        self.appendMessage = appendMessage
    }

    static let preview = ChatHistoryClient(
        loadMessages: { _ in [] },
        saveConversation: { _ in },
        appendMessage: { _, _ in }
    )
}

// MARK: - Live (SwiftData)

extension ChatHistoryClient {
    @MainActor
    static func live(modelContainer: ModelContainer) -> Self {
        Self(
            loadMessages: { @MainActor conversationID in
                let context = ModelContext(modelContainer)
                guard let entity = try Self.fetchConversation(conversationID, in: context) else {
                    return []
                }
                return entity.messages
                    .sorted { $0.order < $1.order }
                    .compactMap(Self.message(from:))
            },
            saveConversation: { @MainActor conversation in
                let context = ModelContext(modelContainer)
                let entity: SidePanelConversationEntity
                if let existing = try Self.fetchConversation(conversation.id, in: context) {
                    entity = existing
                    entity.title = conversation.title
                    entity.updatedAt = conversation.updatedAt
                } else {
                    entity = SidePanelConversationEntity(
                        id: conversation.id,
                        title: conversation.title,
                        createdAt: conversation.createdAt,
                        updatedAt: conversation.updatedAt,
                        isPinned: conversation.isPinned,
                        groupName: conversation.groupName
                    )
                    context.insert(entity)
                }
                try context.save()
            },
            appendMessage: { @MainActor conversationID, message in
                let context = ModelContext(modelContainer)
                guard let conversation = try Self.fetchConversation(conversationID, in: context) else {
                    return
                }

                if let existing = conversation.messages.first(where: { $0.id == message.id }) {
                    Self.apply(message, to: existing)
                } else {
                    let nextOrder = (conversation.messages.map(\.order).max() ?? -1) + 1
                    let entity = Self.entity(from: message, order: nextOrder)
                    entity.conversation = conversation
                    conversation.messages.append(entity)
                    context.insert(entity)
                }
                conversation.updatedAt = message.timestamp
                try context.save()
            }
        )
    }

    @MainActor
    private static func fetchConversation(
        _ id: UUID,
        in context: ModelContext
    ) throws -> SidePanelConversationEntity? {
        var descriptor = FetchDescriptor<SidePanelConversationEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func message(from entity: SidePanelMessageEntity) -> ChatMessage? {
        let kind = ChatMessageKind(rawValue: entity.kindRaw) ?? .text
        let role = ChatMessageRole(rawValue: entity.role) ?? .assistant

        switch kind {
        case .text:
            return .text(
                id: entity.id,
                role: role,
                content: entity.content,
                isComplete: entity.isComplete,
                timestamp: entity.timestamp
            )
        case .thinking:
            return .thinking(
                id: entity.id,
                content: entity.content,
                isComplete: entity.isComplete,
                timestamp: entity.timestamp
            )
        case .system:
            return .system(id: entity.id, content: entity.content, timestamp: entity.timestamp)
        }
    }

    private static func entity(from message: ChatMessage, order: Int) -> SidePanelMessageEntity {
        switch message {
        case let .text(text):
            return SidePanelMessageEntity(
                id: text.id,
                kindRaw: ChatMessageKind.text.rawValue,
                role: text.role.rawValue,
                content: text.content,
                isComplete: text.isComplete,
                timestamp: text.timestamp,
                order: order
            )
        case let .thinking(thinking):
            return SidePanelMessageEntity(
                id: thinking.id,
                kindRaw: ChatMessageKind.thinking.rawValue,
                role: thinking.role.rawValue,
                content: thinking.content,
                isComplete: thinking.isComplete,
                timestamp: thinking.timestamp,
                order: order
            )
        case let .system(system):
            return SidePanelMessageEntity(
                id: system.id,
                kindRaw: ChatMessageKind.system.rawValue,
                role: system.role.rawValue,
                content: system.content,
                isComplete: true,
                timestamp: system.timestamp,
                order: order
            )
        }
    }

    private static func apply(_ message: ChatMessage, to entity: SidePanelMessageEntity) {
        switch message {
        case let .text(text):
            entity.kindRaw = ChatMessageKind.text.rawValue
            entity.role = text.role.rawValue
            entity.content = text.content
            entity.isComplete = text.isComplete
            entity.timestamp = text.timestamp
        case let .thinking(thinking):
            entity.kindRaw = ChatMessageKind.thinking.rawValue
            entity.role = thinking.role.rawValue
            entity.content = thinking.content
            entity.isComplete = thinking.isComplete
            entity.timestamp = thinking.timestamp
        case let .system(system):
            entity.kindRaw = ChatMessageKind.system.rawValue
            entity.role = system.role.rawValue
            entity.content = system.content
            entity.isComplete = true
            entity.timestamp = system.timestamp
        }
    }
}
