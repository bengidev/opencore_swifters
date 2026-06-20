import Foundation
import SwiftData

// MARK: - Placeholder message type

/// Minimal message struct that types the history client's `loadMessages`
/// and `appendMessage` closures. This is a placeholder pending a full Chat
/// feature — it carries only the fields the SwiftData entity stores.
struct SidePanelMessage: Equatable, Identifiable, Sendable {
    let id: UUID
    let role: String
    let content: String
    let createdAt: Date
}

// MARK: - Client

/// Persistence boundary for side panel history. Pure domain types cross this
/// API; SwiftData entities never leak past it.
struct SidePanelHistoryClient: Sendable {
    /// All conversations, most-recently-updated first, for the sidebar list.
    var listConversations: @Sendable () async throws -> [SidePanelConversation]
    /// Restore the ordered messages for a conversation when it is reopened.
    var loadMessages: @Sendable (_ conversationID: UUID) async throws -> [SidePanelMessage]
    /// Upsert a conversation's metadata (id/title/timestamps).
    var saveConversation: @Sendable (_ conversation: SidePanelConversation) async throws -> Void
    /// Append (or upsert by id) a single message into a conversation.
    var appendMessage: @Sendable (_ conversationID: UUID, _ message: SidePanelMessage) async throws -> Void
    /// Delete a conversation and its messages.
    var deleteConversation: @Sendable (_ conversationID: UUID) async throws -> Void
    /// Pin or unpin a conversation, floating it to the top of history.
    var setPinned: @Sendable (_ conversationID: UUID, _ isPinned: Bool) async throws -> Void
    /// Rename a conversation's title.
    var renameConversation: @Sendable (_ conversationID: UUID, _ title: String) async throws -> Void
    /// Assign a conversation to a named group, or ungroup if groupName is nil.
    var setGroup: @Sendable (_ conversationID: UUID, _ groupName: String?) async throws -> Void
    /// List all distinct group names currently in use across conversations.
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

    /// Inert no-op store used by tests and previews. Returns empty lists,
    /// drops writes. The app overrides this with `.live(modelContainer:)`
    /// in the root feature.
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

// MARK: - Live (SwiftData)

extension SidePanelHistoryClient {
    /// Live client backed by SwiftData. Each call opens a fresh `ModelContext`
    /// on the container; mapping to/from the pure domain types happens here at
    /// the boundary so consumers never see an entity.
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
            loadMessages: { @MainActor conversationID in
                let context = ModelContext(modelContainer)
                guard let entity = try Self.fetchConversation(conversationID, in: context) else {
                    return []
                }
                return entity.messages
                    .sorted { $0.order < $1.order }
                    .map(Self.message(from:))
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
                        updatedAt: conversation.updatedAt
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
                conversation.updatedAt = message.createdAt
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

    // MARK: Entity <-> Domain

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

    private static func message(from entity: SidePanelMessageEntity) -> SidePanelMessage {
        SidePanelMessage(
            id: entity.id,
            role: entity.role,
            content: entity.content,
            createdAt: entity.timestamp
        )
    }

    private static func entity(from message: SidePanelMessage, order: Int) -> SidePanelMessageEntity {
        SidePanelMessageEntity(
            id: message.id,
            role: message.role,
            content: message.content,
            timestamp: message.createdAt,
            order: order
        )
    }

    private static func apply(_ message: SidePanelMessage, to entity: SidePanelMessageEntity) {
        entity.role = message.role
        entity.content = message.content
        entity.timestamp = message.createdAt
    }
}
