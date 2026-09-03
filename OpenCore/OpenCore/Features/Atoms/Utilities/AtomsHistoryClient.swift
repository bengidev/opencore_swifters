import Foundation
import SwiftData

struct AtomMessage: Equatable, Identifiable, Sendable {
    let id: UUID
    let role: String
    let content: String
    let createdAt: Date
}

struct AtomsHistoryClient: Sendable {
    var listAtomEntries: @Sendable () async throws -> [AtomListEntry]
    var listAtoms: @Sendable () async throws -> [Atom]
    var loadMessages: @Sendable (_ atomID: UUID) async throws -> [AtomMessage]
    var saveAtom: @Sendable (_ atom: Atom) async throws -> Void
    var appendMessage: @Sendable (_ atomID: UUID, _ message: AtomMessage) async throws -> Void
    var deleteAtom: @Sendable (_ atomID: UUID) async throws -> Void
    var setPinned: @Sendable (_ atomID: UUID, _ isPinned: Bool) async throws -> Void
    var renameAtom: @Sendable (_ atomID: UUID, _ title: String) async throws -> Void
    var setGroup: @Sendable (_ atomID: UUID, _ groupName: String?) async throws -> Void
    var listGroups: @Sendable () async throws -> [String]

    init(
        listAtomEntries: @escaping @Sendable () async throws -> [AtomListEntry],
        listAtoms: @escaping @Sendable () async throws -> [Atom],
        loadMessages: @escaping @Sendable (UUID) async throws -> [AtomMessage],
        saveAtom: @escaping @Sendable (Atom) async throws -> Void,
        appendMessage: @escaping @Sendable (UUID, AtomMessage) async throws -> Void,
        deleteAtom: @escaping @Sendable (UUID) async throws -> Void,
        setPinned: @escaping @Sendable (UUID, Bool) async throws -> Void,
        renameAtom: @escaping @Sendable (UUID, String) async throws -> Void,
        setGroup: @escaping @Sendable (UUID, String?) async throws -> Void,
        listGroups: @escaping @Sendable () async throws -> [String]
    ) {
        self.listAtomEntries = listAtomEntries
        self.listAtoms = listAtoms
        self.loadMessages = loadMessages
        self.saveAtom = saveAtom
        self.appendMessage = appendMessage
        self.deleteAtom = deleteAtom
        self.setPinned = setPinned
        self.renameAtom = renameAtom
        self.setGroup = setGroup
        self.listGroups = listGroups
    }

    static let preview = AtomsHistoryClient(
        listAtomEntries: { [] },
        listAtoms: { [] },
        loadMessages: { _ in [] },
        saveAtom: { _ in },
        appendMessage: { _, _ in },
        deleteAtom: { _ in },
        setPinned: { _, _ in },
        renameAtom: { _, _ in },
        setGroup: { _, _ in },
        listGroups: { [] }
    )
}

extension AtomsHistoryClient {
    @MainActor
    static func live(modelContainer: ModelContainer) -> Self {
        let store = PersistenceAtomHistoryStore.live(modelContainer: modelContainer)
        return Self(
            listAtomEntries: { try await store.listAtomEntries() },
            listAtoms: { try await store.listAtoms() },
            loadMessages: { @MainActor atomID in
                let messages = try await store.loadChatMessages(atomID: atomID)
                return messages.compactMap(Self.atomMessage(from:))
            },
            saveAtom: { @MainActor atom in
                try await store.saveAtom(atom)
            },
            appendMessage: { @MainActor atomID, message in
                guard let chatMessage = Self.chatMessage(from: message) else { return }
                try await store.appendChatMessage(atomID: atomID, message: chatMessage)
            },
            deleteAtom: { try await store.deleteAtom(atomID: $0) },
            setPinned: { try await store.setPinned(atomID: $0, isPinned: $1) },
            renameAtom: { try await store.renameAtom(atomID: $0, title: $1) },
            setGroup: { try await store.setGroup(atomID: $0, groupName: $1) },
            listGroups: { try await store.listGroups() }
        )
    }

    @MainActor
    private static func atomMessage(from message: ChatMessage) -> AtomMessage? {
        switch message {
        case let .text(text):
            return AtomMessage(
                id: text.id,
                role: text.role.rawValue,
                content: text.content,
                createdAt: text.timestamp
            )
        case let .system(system):
            return AtomMessage(
                id: system.id,
                role: system.role.rawValue,
                content: system.content,
                createdAt: system.timestamp
            )
        case .thinking:
            return nil
        case let .outputStream(outputStream):
            return AtomMessage(
                id: outputStream.id,
                role: outputStream.role.rawValue,
                content: outputStream.command,
                createdAt: outputStream.timestamp
            )
        }
    }

    @MainActor
    private static func chatMessage(from message: AtomMessage) -> ChatMessage? {
        let role = ChatMessageRole(rawValue: message.role) ?? .user
        return .text(
            id: message.id,
            role: role,
            content: message.content,
            timestamp: message.createdAt
        )
    }
}
