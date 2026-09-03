import Foundation

/// Pure domain model for a persisted atom — session metadata plus chat history.
///
/// `groupName` places the atom into a named folder in the Atoms list.
/// `nil` means the atom is ungrouped (appears in its created-date section).
nonisolated struct Atom: Equatable, Identifiable, Sendable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var groupName: String?

    nonisolated init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isPinned: Bool = false,
        groupName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
        self.groupName = groupName
    }
}

/// Row model for the Atoms list — atom metadata plus last-message preview.
nonisolated struct AtomListEntry: Equatable, Identifiable, Sendable {
    var id: UUID { atom.id }
    var atom: Atom
    let lastMessagePreview: String
    let lastMessageAt: Date
}
