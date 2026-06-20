import Foundation

/// Pure domain model for a conversation in the side panel.
///
/// `groupName` places the conversation into a named folder in the history
/// sidebar. `nil` means the conversation is ungrouped (appears in its
/// recency bucket).
nonisolated struct SidePanelConversation: Equatable, Identifiable, Sendable {
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
