import Foundation

/// Snapshot of chat flow data mutated through commands and streaming handlers.
nonisolated struct ChatFlowState: Equatable, Sendable {
    var atom: Atom?
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
    var streamingRevision = 0

    var hasMessages: Bool { !messages.isEmpty }

    var showsStreamingStatusCapsule: Bool {
        isSending && streamingStatus == .running
    }

    init(
        atom: Atom? = nil,
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
        self.atom = atom
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
