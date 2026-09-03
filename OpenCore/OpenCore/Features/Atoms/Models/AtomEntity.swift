import Foundation
import SwiftData

/// SwiftData model for a persisted atom. The pure domain type (`Atom`) is
/// mapped to and from this entity only at the persistence boundary.
@Model
final class AtomEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool = false
    var groupName: String?

    @Relationship(deleteRule: .cascade, inverse: \AtomMessageEntity.atom)
    var messages: [AtomMessageEntity]

    init(
        id: UUID,
        title: String,
        createdAt: Date,
        updatedAt: Date,
        isPinned: Bool = false,
        groupName: String? = nil,
        messages: [AtomMessageEntity] = []
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

/// SwiftData model for a persisted chat message within an atom.
@Model
final class AtomMessageEntity {
    @Attribute(.unique) var id: UUID
    var kindRaw: String = ChatMessageKind.text.rawValue
    var role: String
    var content: String
    var isComplete: Bool = true
    var timestamp: Date
    var order: Int
    var detailJSON: String?

    var atom: AtomEntity?

    init(
        id: UUID,
        kindRaw: String = ChatMessageKind.text.rawValue,
        role: String,
        content: String,
        isComplete: Bool = true,
        timestamp: Date,
        order: Int,
        detailJSON: String? = nil,
        atom: AtomEntity? = nil
    ) {
        self.id = id
        self.kindRaw = kindRaw
        self.role = role
        self.content = content
        self.isComplete = isComplete
        self.timestamp = timestamp
        self.order = order
        self.detailJSON = detailJSON
        self.atom = atom
    }
}
