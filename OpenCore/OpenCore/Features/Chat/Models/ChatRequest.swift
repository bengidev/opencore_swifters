import Foundation

nonisolated struct ChatRequest: Equatable, Sendable {
    let conversationID: UUID
    let messages: [ChatMessage]
    let providerID: String
    let modelID: String
    let reasoningEffort: String?
    /// OpenRouter `provider.sort.by` value, or `nil` for default routing.
    let providerSortBy: String?

    init(
        conversationID: UUID,
        messages: [ChatMessage],
        providerID: String,
        modelID: String,
        reasoningEffort: String? = nil,
        providerSortBy: String? = nil
    ) {
        self.conversationID = conversationID
        self.messages = messages
        self.providerID = providerID
        self.modelID = modelID
        self.reasoningEffort = reasoningEffort
        self.providerSortBy = providerSortBy
    }
}

extension ChatRequest {
    var latestUserText: String {
        Self.latestUserText(in: messages)
    }

    static func latestUserText(in messages: [ChatMessage]) -> String {
        messages
            .reversed()
            .compactMap { message -> String? in
                if case let .text(textMessage) = message, textMessage.role == .user {
                    return textMessage.content
                }
                return nil
            }
            .first ?? ""
    }
}
