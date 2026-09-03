import Foundation

/// Persistence boundary for chat history. Delegates to the shared repository.
nonisolated struct ChatHistoryClient: Sendable {
    /// Raw message entries in chronological order (full append-only history).
    var loadMessages: @Sendable (_ atomID: UUID) async throws -> [ChatMessage]
    /// Compaction-aware thread for chat UI and model context (summary + kept tail).
    var loadProjectedMessages: @Sendable (_ atomID: UUID) async throws -> [ChatMessage]
    var loadSessionEntries: @Sendable (_ atomID: UUID) async throws -> [AtomSessionEntry]
    var loadLeafEntryID: @Sendable (_ atomID: UUID) async throws -> UUID?
    var saveAtom: @Sendable (_ atom: Atom) async throws -> Void
    var appendMessage: @Sendable (_ atomID: UUID, _ message: ChatMessage) async throws -> Void
    var replaceMessages: @Sendable (_ atomID: UUID, _ messages: [ChatMessage]) async throws -> Void
    var appendCompaction: @Sendable (_ atomID: UUID, _ checkpoint: AtomCompactionCheckpoint) async throws -> Void

    init(
        loadMessages: @escaping @Sendable (UUID) async throws -> [ChatMessage],
        loadProjectedMessages: @escaping @Sendable (UUID) async throws -> [ChatMessage],
        loadSessionEntries: @escaping @Sendable (UUID) async throws -> [AtomSessionEntry],
        loadLeafEntryID: @escaping @Sendable (UUID) async throws -> UUID?,
        saveAtom: @escaping @Sendable (Atom) async throws -> Void,
        appendMessage: @escaping @Sendable (UUID, ChatMessage) async throws -> Void,
        replaceMessages: @escaping @Sendable (UUID, [ChatMessage]) async throws -> Void,
        appendCompaction: @escaping @Sendable (UUID, AtomCompactionCheckpoint) async throws -> Void
    ) {
        self.loadMessages = loadMessages
        self.loadProjectedMessages = loadProjectedMessages
        self.loadSessionEntries = loadSessionEntries
        self.loadLeafEntryID = loadLeafEntryID
        self.saveAtom = saveAtom
        self.appendMessage = appendMessage
        self.replaceMessages = replaceMessages
        self.appendCompaction = appendCompaction
    }

    static let preview = ChatHistoryClient(
        loadMessages: { _ in [] },
        loadProjectedMessages: { _ in [] },
        loadSessionEntries: { _ in [] },
        loadLeafEntryID: { _ in nil },
        saveAtom: { _ in },
        appendMessage: { _, _ in },
        replaceMessages: { _, _ in },
        appendCompaction: { _, _ in }
    )
}

extension ChatHistoryClient {
    static func live(store: PersistenceAtomHistoryStore) -> Self {
        Self(
            loadMessages: { try await store.loadChatMessages(atomID: $0) },
            loadProjectedMessages: { try await store.loadProjectedChatMessages(atomID: $0) },
            loadSessionEntries: { try await store.loadSessionEntries(atomID: $0) },
            loadLeafEntryID: { try await store.loadLeafEntryID(atomID: $0) },
            saveAtom: { try await store.saveAtom($0) },
            appendMessage: { try await store.appendChatMessage(atomID: $0, message: $1) },
            replaceMessages: { try await store.replaceChatMessages(atomID: $0, messages: $1) },
            appendCompaction: { try await store.appendCompaction(atomID: $0, checkpoint: $1) }
        )
    }

    static func testing(
        loadMessages: @escaping @Sendable (UUID) async throws -> [ChatMessage] = { _ in [] },
        loadProjectedMessages: @escaping @Sendable (UUID) async throws -> [ChatMessage] = { _ in [] },
        loadSessionEntries: @escaping @Sendable (UUID) async throws -> [AtomSessionEntry] = { _ in [] },
        loadLeafEntryID: @escaping @Sendable (UUID) async throws -> UUID? = { _ in nil },
        saveAtom: @escaping @Sendable (Atom) async throws -> Void = { _ in },
        appendMessage: @escaping @Sendable (UUID, ChatMessage) async throws -> Void = { _, _ in },
        replaceMessages: @escaping @Sendable (UUID, [ChatMessage]) async throws -> Void = { _, _ in },
        appendCompaction: @escaping @Sendable (UUID, AtomCompactionCheckpoint) async throws -> Void = { _, _ in }
    ) -> Self {
        Self(
            loadMessages: loadMessages,
            loadProjectedMessages: loadProjectedMessages,
            loadSessionEntries: loadSessionEntries,
            loadLeafEntryID: loadLeafEntryID,
            saveAtom: saveAtom,
            appendMessage: appendMessage,
            replaceMessages: replaceMessages,
            appendCompaction: appendCompaction
        )
    }
}
