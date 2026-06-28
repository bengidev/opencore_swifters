import Foundation
import SwiftData

enum PersistenceConversationHistoryError: Error, Equatable {
    case conversationNotFound(UUID)
}

/// SwiftData repository adapter for `PersistenceConversationHistoryStoring`.
extension PersistenceConversationHistoryStore {
    @MainActor
    static func live(modelContainer: ModelContainer) -> Self {
        Self(
            listConversations: { @MainActor in
                let context = ModelContext(modelContainer)
                let descriptor = FetchDescriptor<SidePanelConversationEntity>(
                    sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
                )
                let mapped = try context.fetch(descriptor)
                    .map(Self.conversation(from:))
                    .sorted { lhs, rhs in
                        if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                        return lhs.updatedAt > rhs.updatedAt
                    }
                var seen = Set<UUID>()
                return mapped.filter { seen.insert($0.id).inserted }
            },
            loadChatMessages: { @MainActor conversationID in
                let context = ModelContext(modelContainer)
                guard let entity = try Self.fetchConversation(conversationID, in: context) else {
                    return []
                }
                return entity.messages
                    .sorted { $0.order < $1.order }
                    .compactMap(Self.chatMessage(from:))
            },
            saveConversation: { @MainActor conversation in
                let context = ModelContext(modelContainer)
                let entity: SidePanelConversationEntity
                if let existing = try Self.fetchConversation(conversation.id, in: context) {
                    entity = existing
                    entity.title = conversation.title
                    entity.updatedAt = conversation.updatedAt
                    entity.isPinned = conversation.isPinned
                    entity.groupName = conversation.groupName
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
            appendChatMessage: { @MainActor conversationID, message in
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
            },
            replaceChatMessages: { @MainActor conversationID, messages in
                let context = ModelContext(modelContainer)
                guard let conversation = try Self.fetchConversation(conversationID, in: context) else {
                    throw PersistenceConversationHistoryError.conversationNotFound(conversationID)
                }

                for entity in conversation.messages {
                    context.delete(entity)
                }
                conversation.messages.removeAll()

                for (order, message) in messages.enumerated() {
                    let entity = Self.entity(from: message, order: order)
                    entity.conversation = conversation
                    conversation.messages.append(entity)
                    context.insert(entity)
                }

                if let last = messages.last {
                    conversation.updatedAt = last.timestamp
                }
                try context.save()
            },
            deleteConversation: { @MainActor conversationID in
                let context = ModelContext(modelContainer)
                guard let entity = try Self.fetchConversation(conversationID, in: context) else {
                    return
                }
                context.delete(entity)
                try context.save()
            },
            setPinned: { @MainActor conversationID, isPinned in
                let context = ModelContext(modelContainer)
                guard let entity = try Self.fetchConversation(conversationID, in: context) else {
                    return
                }
                entity.isPinned = isPinned
                try context.save()
            },
            renameConversation: { @MainActor conversationID, title in
                let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                let context = ModelContext(modelContainer)
                guard let entity = try Self.fetchConversation(conversationID, in: context) else {
                    return
                }
                entity.title = trimmed
                entity.updatedAt = .now
                try context.save()
            },
            setGroup: { @MainActor conversationID, groupName in
                let context = ModelContext(modelContainer)
                guard let entity = try Self.fetchConversation(conversationID, in: context) else {
                    return
                }
                if let groupName {
                    let trimmed = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    entity.groupName = trimmed
                } else {
                    entity.groupName = nil
                }
                try context.save()
            },
            listGroups: { @MainActor in
                let context = ModelContext(modelContainer)
                let descriptor = FetchDescriptor<SidePanelConversationEntity>(
                    predicate: #Predicate { $0.groupName != nil }
                )
                let entities = try context.fetch(descriptor)
                let groups = Set(entities.compactMap(\.groupName))
                return groups.sorted()
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

    @MainActor
    private static func conversation(from entity: SidePanelConversationEntity) -> SidePanelConversation {
        SidePanelConversation(
            id: entity.id,
            title: entity.title,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt,
            isPinned: entity.isPinned,
            groupName: entity.groupName
        )
    }

    @MainActor
    private static func chatMessage(from entity: SidePanelMessageEntity) -> ChatMessage? {
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
        case .outputStream:
            let detail = Self.decodeOutputStreamDetail(from: entity.detailJSON)
            return .outputStream(
                id: entity.id,
                command: entity.content,
                detail: detail,
                isComplete: entity.isComplete,
                timestamp: entity.timestamp
            )
        }
    }

    @MainActor
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
        case let .outputStream(outputStream):
            return SidePanelMessageEntity(
                id: outputStream.id,
                kindRaw: ChatMessageKind.outputStream.rawValue,
                role: outputStream.role.rawValue,
                content: outputStream.command,
                isComplete: outputStream.isComplete,
                timestamp: outputStream.timestamp,
                order: order,
                detailJSON: Self.encodeOutputStreamDetail(outputStream.detail)
            )
        }
    }

    @MainActor
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
            entity.detailJSON = nil
        case let .outputStream(outputStream):
            entity.kindRaw = ChatMessageKind.outputStream.rawValue
            entity.role = outputStream.role.rawValue
            entity.content = outputStream.command
            entity.isComplete = outputStream.isComplete
            entity.timestamp = outputStream.timestamp
            entity.detailJSON = Self.encodeOutputStreamDetail(outputStream.detail)
        }
    }

    @MainActor
    private static func encodeOutputStreamDetail(_ detail: ChatOutputStreamDetail) -> String? {
        guard let data = try? JSONEncoder().encode(detail) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @MainActor
    private static func decodeOutputStreamDetail(from json: String?) -> ChatOutputStreamDetail {
        guard let json,
              let data = json.data(using: .utf8),
              let detail = try? JSONDecoder().decode(ChatOutputStreamDetail.self, from: data) else {
            return ChatOutputStreamDetail()
        }
        return detail
    }
}
