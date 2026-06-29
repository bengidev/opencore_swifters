import Foundation

/// Snapshot of chat flow data mutated through commands and streaming handlers.
nonisolated struct ChatFlowState: Equatable, Sendable {
    var conversation: SidePanelConversation?
    var messages: [ChatMessage] = []
    var draftMessage = ""
    var draftAttachments: [ChatMessageAttachment] = []
    var isSending = false
    var streamingStatus: ChatStreamingStatus = .idle
    var currentPartialText = ""
    var currentPartialThinking = ""
    var streamErrorMessage: String?
    var streamingThinkingID: UUID?
    var streamingAnswerID: UUID?
    var streamingOutputStreamID: UUID?
    /// Bumped when batched streaming content is applied to `messages` (scroll anchor).
    var streamingRevision = 0

    var hasMessages: Bool { !messages.isEmpty }

    /// True while a turn is actively streaming; drives the status capsule above the composer.
    var showsStreamingStatusCapsule: Bool {
        isSending && streamingStatus == .running
    }

    init(
        conversation: SidePanelConversation? = nil,
        messages: [ChatMessage] = [],
        draftMessage: String = "",
        draftAttachments: [ChatMessageAttachment] = [],
        isSending: Bool = false,
        streamingStatus: ChatStreamingStatus = .idle,
        currentPartialText: String = "",
        currentPartialThinking: String = "",
        streamErrorMessage: String? = nil,
        streamingThinkingID: UUID? = nil,
        streamingAnswerID: UUID? = nil,
        streamingOutputStreamID: UUID? = nil,
        streamingRevision: Int = 0
    ) {
        self.conversation = conversation
        self.messages = messages
        self.draftMessage = draftMessage
        self.draftAttachments = draftAttachments
        self.isSending = isSending
        self.streamingStatus = streamingStatus
        self.currentPartialText = currentPartialText
        self.currentPartialThinking = currentPartialThinking
        self.streamErrorMessage = streamErrorMessage
        self.streamingThinkingID = streamingThinkingID
        self.streamingAnswerID = streamingAnswerID
        self.streamingOutputStreamID = streamingOutputStreamID
        self.streamingRevision = streamingRevision
    }
}
