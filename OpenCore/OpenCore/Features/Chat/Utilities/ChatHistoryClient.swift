import Foundation
import SwiftData

/// Persistence boundary for chat history. Delegates to the shared repository.
nonisolated struct ChatHistoryClient: Sendable {
    var loadMessages: @Sendable (_ atomID: UUID) async throws -> [ChatMessage]
    var saveAtom: @Sendable (_ atom: Atom) async throws -> Void
    var appendMessage: @Sendable (_ atomID: UUID, _ message: ChatMessage) async throws -> Void
    var replaceMessages: @Sendable (_ atomID: UUID, _ messages: [ChatMessage]) async throws -> Void

    init(
        loadMessages: @escaping @Sendable (UUID) async throws -> [ChatMessage],
        saveAtom: @escaping @Sendable (Atom) async throws -> Void,
        appendMessage: @escaping @Sendable (UUID, ChatMessage) async throws -> Void,
        replaceMessages: @escaping @Sendable (UUID, [ChatMessage]) async throws -> Void
    ) {
        self.loadMessages = loadMessages
        self.saveAtom = saveAtom
        self.appendMessage = appendMessage
        self.replaceMessages = replaceMessages
    }

    static let preview = ChatHistoryClient(
        loadMessages: { _ in [] },
        saveAtom: { _ in },
        appendMessage: { _, _ in },
        replaceMessages: { _, _ in }
    )
}

extension ChatHistoryClient {
    @MainActor
    static func live(modelContainer: ModelContainer) -> Self {
        let store = PersistenceAtomHistoryStore.live(modelContainer: modelContainer)
        return Self(
            loadMessages: { try await store.loadChatMessages(atomID: $0) },
            saveAtom: { try await store.saveAtom($0) },
            appendMessage: { try await store.appendChatMessage(atomID: $0, message: $1) },
            replaceMessages: { try await store.replaceChatMessages(atomID: $0, messages: $1) }
        )
    }
}
