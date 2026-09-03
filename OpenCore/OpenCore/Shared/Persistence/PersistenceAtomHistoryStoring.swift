import Foundation

/// Repository contract for atom history. Pure domain types cross this
/// boundary; SwiftData entities never leak past the adapter.
nonisolated protocol PersistenceAtomHistoryStoring: Sendable {
    func listAtomEntries() async throws -> [AtomListEntry]
    func listAtoms() async throws -> [Atom]
    func loadChatMessages(atomID: UUID) async throws -> [ChatMessage]
    func loadProjectedChatMessages(atomID: UUID) async throws -> [ChatMessage]
    func loadSessionEntries(atomID: UUID) async throws -> [AtomSessionEntry]
    func loadLeafEntryID(atomID: UUID) async throws -> UUID?
    func saveAtom(_ atom: Atom) async throws
    func appendChatMessage(atomID: UUID, message: ChatMessage) async throws
    func replaceChatMessages(atomID: UUID, messages: [ChatMessage]) async throws
    func appendCompaction(atomID: UUID, checkpoint: AtomCompactionCheckpoint) async throws
    func deleteAtom(atomID: UUID) async throws
    func setPinned(atomID: UUID, isPinned: Bool) async throws
    func renameAtom(atomID: UUID, title: String) async throws
    func setGroup(atomID: UUID, groupName: String?) async throws
    func listGroups() async throws -> [String]
}

nonisolated struct PersistenceAtomHistoryStore: PersistenceAtomHistoryStoring, Sendable {
    private let _listAtomEntries: @Sendable () async throws -> [AtomListEntry]
    private let _listAtoms: @Sendable () async throws -> [Atom]
    private let _loadChatMessages: @Sendable (UUID) async throws -> [ChatMessage]
    private let _loadProjectedChatMessages: @Sendable (UUID) async throws -> [ChatMessage]
    private let _loadSessionEntries: @Sendable (UUID) async throws -> [AtomSessionEntry]
    private let _loadLeafEntryID: @Sendable (UUID) async throws -> UUID?
    private let _saveAtom: @Sendable (Atom) async throws -> Void
    private let _appendChatMessage: @Sendable (UUID, ChatMessage) async throws -> Void
    private let _replaceChatMessages: @Sendable (UUID, [ChatMessage]) async throws -> Void
    private let _appendCompaction: @Sendable (UUID, AtomCompactionCheckpoint) async throws -> Void
    private let _deleteAtom: @Sendable (UUID) async throws -> Void
    private let _setPinned: @Sendable (UUID, Bool) async throws -> Void
    private let _renameAtom: @Sendable (UUID, String) async throws -> Void
    private let _setGroup: @Sendable (UUID, String?) async throws -> Void
    private let _listGroups: @Sendable () async throws -> [String]

    init(
        listAtomEntries: @escaping @Sendable () async throws -> [AtomListEntry],
        listAtoms: @escaping @Sendable () async throws -> [Atom],
        loadChatMessages: @escaping @Sendable (UUID) async throws -> [ChatMessage],
        loadProjectedChatMessages: @escaping @Sendable (UUID) async throws -> [ChatMessage],
        loadSessionEntries: @escaping @Sendable (UUID) async throws -> [AtomSessionEntry],
        loadLeafEntryID: @escaping @Sendable (UUID) async throws -> UUID?,
        saveAtom: @escaping @Sendable (Atom) async throws -> Void,
        appendChatMessage: @escaping @Sendable (UUID, ChatMessage) async throws -> Void,
        replaceChatMessages: @escaping @Sendable (UUID, [ChatMessage]) async throws -> Void,
        appendCompaction: @escaping @Sendable (UUID, AtomCompactionCheckpoint) async throws -> Void,
        deleteAtom: @escaping @Sendable (UUID) async throws -> Void,
        setPinned: @escaping @Sendable (UUID, Bool) async throws -> Void,
        renameAtom: @escaping @Sendable (UUID, String) async throws -> Void,
        setGroup: @escaping @Sendable (UUID, String?) async throws -> Void,
        listGroups: @escaping @Sendable () async throws -> [String]
    ) {
        _listAtomEntries = listAtomEntries
        _listAtoms = listAtoms
        _loadChatMessages = loadChatMessages
        _loadProjectedChatMessages = loadProjectedChatMessages
        _loadSessionEntries = loadSessionEntries
        _loadLeafEntryID = loadLeafEntryID
        _saveAtom = saveAtom
        _appendChatMessage = appendChatMessage
        _replaceChatMessages = replaceChatMessages
        _appendCompaction = appendCompaction
        _deleteAtom = deleteAtom
        _setPinned = setPinned
        _renameAtom = renameAtom
        _setGroup = setGroup
        _listGroups = listGroups
    }

    func listAtomEntries() async throws -> [AtomListEntry] {
        try await _listAtomEntries()
    }

    func listAtoms() async throws -> [Atom] {
        try await _listAtoms()
    }

    func loadChatMessages(atomID: UUID) async throws -> [ChatMessage] {
        try await _loadChatMessages(atomID)
    }

    func loadProjectedChatMessages(atomID: UUID) async throws -> [ChatMessage] {
        try await _loadProjectedChatMessages(atomID)
    }

    func loadSessionEntries(atomID: UUID) async throws -> [AtomSessionEntry] {
        try await _loadSessionEntries(atomID)
    }

    func loadLeafEntryID(atomID: UUID) async throws -> UUID? {
        try await _loadLeafEntryID(atomID)
    }

    func saveAtom(_ atom: Atom) async throws {
        try await _saveAtom(atom)
    }

    func appendChatMessage(atomID: UUID, message: ChatMessage) async throws {
        try await _appendChatMessage(atomID, message)
    }

    func replaceChatMessages(atomID: UUID, messages: [ChatMessage]) async throws {
        try await _replaceChatMessages(atomID, messages)
    }

    func appendCompaction(atomID: UUID, checkpoint: AtomCompactionCheckpoint) async throws {
        try await _appendCompaction(atomID, checkpoint)
    }

    func deleteAtom(atomID: UUID) async throws {
        try await _deleteAtom(atomID)
    }

    func setPinned(atomID: UUID, isPinned: Bool) async throws {
        try await _setPinned(atomID, isPinned)
    }

    func renameAtom(atomID: UUID, title: String) async throws {
        try await _renameAtom(atomID, title)
    }

    func setGroup(atomID: UUID, groupName: String?) async throws {
        try await _setGroup(atomID, groupName)
    }

    func listGroups() async throws -> [String] {
        try await _listGroups()
    }

    nonisolated static let preview = PersistenceAtomHistoryStore(
        listAtomEntries: { [] },
        listAtoms: { [] },
        loadChatMessages: { _ in [] },
        loadProjectedChatMessages: { _ in [] },
        loadSessionEntries: { _ in [] },
        loadLeafEntryID: { _ in nil },
        saveAtom: { _ in },
        appendChatMessage: { _, _ in },
        replaceChatMessages: { _, _ in },
        appendCompaction: { _, _ in },
        deleteAtom: { _ in },
        setPinned: { _, _ in },
        renameAtom: { _, _ in },
        setGroup: { _, _ in },
        listGroups: { [] }
    )
}

enum PersistenceAtomHistoryError: Error, Equatable {
    case atomNotFound(UUID)
}
