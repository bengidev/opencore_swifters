import Foundation
import SwiftData

/// SwiftData model for a persisted conversation. The pure domain type
/// (`SidePanelConversation`) is mapped to and from this entity only at the
/// `SidePanelHistoryClient` boundary — consumers never see SwiftData.
@Model
final class SidePanelConversationEntity {
    /// Domain conversation id. Unique so re-persisting an existing
    /// conversation upserts rather than duplicating.
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    /// Whether the user pinned this conversation to the top of history.
    /// Additive field — defaults to false so existing stores migrate cleanly.
    var isPinned: Bool = false
    /// Optional group name for sidebar folder organization. `nil` means ungrouped.
    /// Additive field — defaults to nil so existing stores migrate cleanly.
    var groupName: String?

    /// Owned messages. Deleting a conversation cascades to its messages so the
    /// store never accumulates orphaned rows.
    @Relationship(deleteRule: .cascade, inverse: \SidePanelMessageEntity.conversation)
    var messages: [SidePanelMessageEntity]

    init(
        id: UUID,
        title: String,
        createdAt: Date,
        updatedAt: Date,
        isPinned: Bool = false,
        groupName: String? = nil,
        messages: [SidePanelMessageEntity] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
        self.groupName = groupName
        self.messages = messages
    }
}

/// SwiftData model for a persisted message. Minimal placeholder pending a
/// full Chat feature — carries just enough fields so the history client's
/// `loadMessages` / `appendMessage` closures are typed.
@Model
final class SidePanelMessageEntity {
    @Attribute(.unique) var id: UUID
    /// Discriminator for rich chat message kinds (`text`, `thinking`, `system`).
    /// Defaults to `text` so existing stores migrate cleanly.
    var kindRaw: String = ChatMessageKind.text.rawValue
    var role: String
    var content: String
    /// Whether streaming for this row has finished. Defaults to true for legacy rows.
    var isComplete: Bool = true
    var timestamp: Date
    /// Monotonic insertion index within the conversation. Sorting by this
    /// (not timestamp) keeps user/assistant turns in the exact emitted order.
    var order: Int

    var conversation: SidePanelConversationEntity?

    init(
        id: UUID,
        kindRaw: String = ChatMessageKind.text.rawValue,
        role: String,
        content: String,
        isComplete: Bool = true,
        timestamp: Date,
        order: Int,
        conversation: SidePanelConversationEntity? = nil
    ) {
        self.id = id
        self.kindRaw = kindRaw
        self.role = role
        self.content = content
        self.isComplete = isComplete
        self.timestamp = timestamp
        self.order = order
        self.conversation = conversation
    }
}
