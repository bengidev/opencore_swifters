import Foundation

/// Encapsulates a single chat flow mutation.
protocol ChatCommand: Sendable {
    func execute(on state: inout ChatFlowState)
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

struct ChatClearActiveConversationCommand: ChatCommand {
    func execute(on state: inout ChatFlowState) {
        state.conversation = nil
        state.messages = []
        state.draftMessage = ""
        state.isSending = false
        state.streamingStatus = .idle
        state.currentPartialText = ""
        state.currentPartialThinking = ""
        state.streamErrorMessage = nil
        state.streamingThinkingID = nil
        state.streamingAnswerID = nil
        state.streamingRevision = 0
    }
}

struct ChatReopenConversationCommand: ChatCommand {
    let conversation: SidePanelConversation

    func execute(on state: inout ChatFlowState) {
        state.conversation = conversation
        state.messages = []
        state.draftMessage = ""
        state.isSending = false
        state.streamingStatus = .idle
        state.currentPartialText = ""
        state.currentPartialThinking = ""
        state.streamErrorMessage = nil
        state.streamingThinkingID = nil
        state.streamingAnswerID = nil
        state.streamingRevision = 0
    }
}

struct ChatCommandInvoker: Sendable {
    func invoke(_ command: any ChatCommand, on state: inout ChatFlowState) {
        command.execute(on: &state)
    }
}
