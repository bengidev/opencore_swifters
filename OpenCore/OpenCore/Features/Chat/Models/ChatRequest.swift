import Foundation

nonisolated struct ChatRequest: Equatable, Sendable {
    let conversationID: UUID
    let messages: [ChatMessage]
    let provider: SidePanelProviderAPI
    let modelID: String
    let reasoningEffort: String?

    init(
        conversationID: UUID,
        messages: [ChatMessage],
        provider: SidePanelProviderAPI,
        modelID: String,
        reasoningEffort: String? = nil
    ) {
        self.conversationID = conversationID
        self.messages = messages
        self.provider = provider
        self.modelID = modelID
        self.reasoningEffort = reasoningEffort
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
