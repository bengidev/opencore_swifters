import Foundation

/// Encapsulates a single chat flow mutation.
protocol ChatCommand: Sendable {
    func execute(on state: inout ChatFlowState)
}

struct ChatDraftAttachmentAddedCommand: ChatCommand {
    let attachment: ChatMessageAttachment

    func execute(on state: inout ChatFlowState) {
        state.draftAttachments.append(attachment)
    }
}

struct ChatDraftAttachmentRemovedCommand: ChatCommand {
    let id: UUID

    func execute(on state: inout ChatFlowState) {
        state.draftAttachments.removeAll { $0.id == id }
    }
}

struct ChatDraftAttachmentsClearedCommand: ChatCommand {
    func execute(on state: inout ChatFlowState) {
        state.draftAttachments.removeAll()
    }
}

struct ChatDraftMessageChangedCommand: ChatCommand {
    let text: String

    func execute(on state: inout ChatFlowState) {
        state.draftMessage = text
    }
}

struct ChatErrorDismissedCommand: ChatCommand {
    func execute(on state: inout ChatFlowState) {
        state.streamErrorMessage = nil
        if state.streamingStatus == .failed {
            state.streamingStatus = .idle
        }
    }
}

struct ChatMessagesRestoredCommand: ChatCommand {
    let messages: [ChatMessage]

    func execute(on state: inout ChatFlowState) {
        state.messages = messages
    }
}

struct ChatClearActiveAtomCommand: ChatCommand {
    func execute(on state: inout ChatFlowState) {
        state.atom = nil
        state.messages = []
        state.draftMessage = ""
        state.draftAttachments = []
        state.isSending = false
        state.isCompacting = false
        state.streamingStatus = .idle
        state.currentPartialText = ""
        state.currentPartialThinking = ""
        state.streamErrorMessage = nil
        state.streamingThinkingID = nil
        state.streamingAnswerID = nil
        state.streamingOutputStreamID = nil
        state.streamingRevision = 0
    }
}

struct ChatReopenAtomCommand: ChatCommand {
    let atom: Atom

    func execute(on state: inout ChatFlowState) {
        state.atom = atom
        state.messages = []
        state.draftMessage = ""
        state.draftAttachments = []
        state.isSending = false
        state.isCompacting = false
        state.streamingStatus = .idle
        state.currentPartialText = ""
        state.currentPartialThinking = ""
        state.streamErrorMessage = nil
        state.streamingThinkingID = nil
        state.streamingAnswerID = nil
        state.streamingOutputStreamID = nil
        state.streamingRevision = 0
    }
}

struct ChatCommandInvoker: Sendable {
    func invoke(_ command: any ChatCommand, on state: inout ChatFlowState) {
        command.execute(on: &state)
    }
}
