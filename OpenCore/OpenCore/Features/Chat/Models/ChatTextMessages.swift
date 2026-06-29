import Foundation

nonisolated struct ChatTextMessage: ChatMessagePayload, Equatable, Identifiable, Sendable, Codable {
    let id: UUID
    let role: ChatMessageRole
    var content: String
    var isComplete: Bool
    let timestamp: Date
    var attachments: [ChatMessageAttachment]
    /// Provider-facing text. When nil, `content` is sent to the model.
    var modelContent: String?

    nonisolated init(
        id: UUID = UUID(),
        role: ChatMessageRole,
        content: String,
        isComplete: Bool = true,
        timestamp: Date = Date(),
        attachments: [ChatMessageAttachment] = [],
        modelContent: String? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.isComplete = isComplete
        self.timestamp = timestamp
        self.attachments = attachments
        self.modelContent = modelContent
    }

    var providerContent: String {
        modelContent ?? content
    }
}

nonisolated struct ChatThinkingMessage: ChatMessagePayload, Equatable, Identifiable, Sendable, Codable {
    let id: UUID
    let role: ChatMessageRole
    var content: String
    var isComplete: Bool
    let timestamp: Date

    nonisolated init(
        id: UUID = UUID(),
        role: ChatMessageRole = .assistant,
        content: String,
        isComplete: Bool = true,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.isComplete = isComplete
        self.timestamp = timestamp
    }
}

nonisolated struct ChatSystemMessage: ChatMessagePayload, Equatable, Identifiable, Sendable, Codable {
    let id: UUID
    let role: ChatMessageRole
    var content: String
    let timestamp: Date

    nonisolated init(
        id: UUID = UUID(),
        role: ChatMessageRole = .system,
        content: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}
