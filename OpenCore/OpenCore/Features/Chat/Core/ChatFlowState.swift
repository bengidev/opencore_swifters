import Foundation

/// Snapshot of chat flow data mutated through commands and streaming handlers.
nonisolated struct ChatFlowState: Equatable, Sendable {
    var conversation: SidePanelConversation?
    var messages: [ChatMessage] = []
    var draftMessage = ""
    var isSending = false
    var streamingStatus: ChatStreamingStatus = .idle
    var currentPartialText = ""
    var currentPartialThinking = ""
    var streamErrorMessage: String?
    var streamingThinkingID: UUID?
    var streamingAnswerID: UUID?

    var hasMessages: Bool { !messages.isEmpty }

    init(
        conversation: SidePanelConversation? = nil,
        messages: [ChatMessage] = [],
        draftMessage: String = "",
        isSending: Bool = false,
        streamingStatus: ChatStreamingStatus = .idle,
        currentPartialText: String = "",
        currentPartialThinking: String = "",
        streamErrorMessage: String? = nil,
        streamingThinkingID: UUID? = nil,
        streamingAnswerID: UUID? = nil
    ) {
        self.conversation = conversation
        self.messages = messages
        self.draftMessage = draftMessage
        self.isSending = isSending
        self.streamingStatus = streamingStatus
        self.currentPartialText = currentPartialText
        self.currentPartialThinking = currentPartialThinking
        self.streamErrorMessage = streamErrorMessage
        self.streamingThinkingID = streamingThinkingID
        self.streamingAnswerID = streamingAnswerID
    }
}
