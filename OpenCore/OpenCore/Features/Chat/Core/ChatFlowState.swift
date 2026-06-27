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
    /// Bumped when batched streaming content is applied to `messages` (scroll anchor).
    var streamingRevision = 0
    /// Bumped when history messages are restored so the thread can scroll to the end.
    var threadPresentationRevision = 0

    var hasMessages: Bool { !messages.isEmpty }

    /// True while a turn is actively streaming; drives the status capsule above the composer.
    var showsStreamingStatusCapsule: Bool {
        isSending && streamingStatus == .running
    }

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
        streamingAnswerID: UUID? = nil,
        streamingRevision: Int = 0,
        threadPresentationRevision: Int = 0
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
        self.streamingRevision = streamingRevision
        self.threadPresentationRevision = threadPresentationRevision
    }
}
