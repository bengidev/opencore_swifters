import Foundation

/// Repository contract for conversation history. Pure domain types cross this
/// boundary; SwiftData entities never leak past the adapter.
nonisolated protocol PersistenceConversationHistoryStoring: Sendable {
    func listConversations() async throws -> [SidePanelConversation]
    func loadChatMessages(conversationID: UUID) async throws -> [ChatMessage]
    func saveConversation(_ conversation: SidePanelConversation) async throws
    func appendChatMessage(conversationID: UUID, message: ChatMessage) async throws
    func deleteConversation(conversationID: UUID) async throws
    func setPinned(conversationID: UUID, isPinned: Bool) async throws
    func renameConversation(conversationID: UUID, title: String) async throws
    func setGroup(conversationID: UUID, groupName: String?) async throws
    func listGroups() async throws -> [String]
}

/// Closure-based facade over `PersistenceConversationHistoryStoring` for DI.
nonisolated struct PersistenceConversationHistoryStore: PersistenceConversationHistoryStoring, Sendable {
    private let _listConversations: @Sendable () async throws -> [SidePanelConversation]
    private let _loadChatMessages: @Sendable (UUID) async throws -> [ChatMessage]
    private let _saveConversation: @Sendable (SidePanelConversation) async throws -> Void
    private let _appendChatMessage: @Sendable (UUID, ChatMessage) async throws -> Void
    private let _deleteConversation: @Sendable (UUID) async throws -> Void
    private let _setPinned: @Sendable (UUID, Bool) async throws -> Void
    private let _renameConversation: @Sendable (UUID, String) async throws -> Void
    private let _setGroup: @Sendable (UUID, String?) async throws -> Void
    private let _listGroups: @Sendable () async throws -> [String]

    init(
        listConversations: @escaping @Sendable () async throws -> [SidePanelConversation],
        loadChatMessages: @escaping @Sendable (UUID) async throws -> [ChatMessage],
        saveConversation: @escaping @Sendable (SidePanelConversation) async throws -> Void,
        appendChatMessage: @escaping @Sendable (UUID, ChatMessage) async throws -> Void,
        deleteConversation: @escaping @Sendable (UUID) async throws -> Void,
        setPinned: @escaping @Sendable (UUID, Bool) async throws -> Void,
        renameConversation: @escaping @Sendable (UUID, String) async throws -> Void,
        setGroup: @escaping @Sendable (UUID, String?) async throws -> Void,
        listGroups: @escaping @Sendable () async throws -> [String]
    ) {
        _listConversations = listConversations
        _loadChatMessages = loadChatMessages
        _saveConversation = saveConversation
        _appendChatMessage = appendChatMessage
        _deleteConversation = deleteConversation
        _setPinned = setPinned
        _renameConversation = renameConversation
        _setGroup = setGroup
        _listGroups = listGroups
    }

    func listConversations() async throws -> [SidePanelConversation] {
        try await _listConversations()
    }

    func loadChatMessages(conversationID: UUID) async throws -> [ChatMessage] {
        try await _loadChatMessages(conversationID)
    }

    func saveConversation(_ conversation: SidePanelConversation) async throws {
        try await _saveConversation(conversation)
    }

    func appendChatMessage(conversationID: UUID, message: ChatMessage) async throws {
        try await _appendChatMessage(conversationID, message)
    }

    func deleteConversation(conversationID: UUID) async throws {
        try await _deleteConversation(conversationID)
    }

    func setPinned(conversationID: UUID, isPinned: Bool) async throws {
        try await _setPinned(conversationID, isPinned)
    }

    func renameConversation(conversationID: UUID, title: String) async throws {
        try await _renameConversation(conversationID, title)
    }

    func setGroup(conversationID: UUID, groupName: String?) async throws {
        try await _setGroup(conversationID, groupName)
    }

    func listGroups() async throws -> [String] {
        try await _listGroups()
    }

    nonisolated static let preview = PersistenceConversationHistoryStore(
        listConversations: { [] },
        loadChatMessages: { _ in [] },
        saveConversation: { _ in },
        appendChatMessage: { _, _ in },
        deleteConversation: { _ in },
        setPinned: { _, _ in },
        renameConversation: { _, _ in },
        setGroup: { _, _ in },
        listGroups: { [] }
    )
}
