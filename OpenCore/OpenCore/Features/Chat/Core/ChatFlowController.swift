import Foundation
import Observation

/// Single entry point for live chat — message thread, streaming merge logic,
/// send/retry/reopen, and turn-boundary persistence.
@MainActor
@Observable
final class ChatFlowController {
    private(set) var state: ChatFlowState
    private let streaming: ChatStreamingClient
    private let history: ChatHistoryClient
    private let providerPreference: any SidePanelProviderPreferenceStore
    private let invoker = ChatCommandInvoker()
    private var streamTask: Task<Void, Never>?
    private let makeID: () -> UUID
    private let now: () -> Date

    init(
        state: ChatFlowState = ChatFlowState(),
        streaming: ChatStreamingClient = .preview,
        history: ChatHistoryClient = .preview,
        providerPreference: any SidePanelProviderPreferenceStore = SidePanelInMemoryProviderPreferenceStore(),
        makeID: @escaping () -> UUID = UUID.init,
        now: @escaping () -> Date = Date.init
    ) {
        self.state = state
        self.streaming = streaming
        self.history = history
        self.providerPreference = providerPreference
        self.makeID = makeID
        self.now = now
    }

    // MARK: - Dispatch

    func dispatch(_ command: any ChatCommand) {
        invoker.invoke(command, on: &state)
    }

    func setDraftMessage(_ text: String) {
        dispatch(ChatDraftMessageChangedCommand(text: text))
    }

    func dismissError() {
        dispatch(ChatErrorDismissedCommand())
    }

    func clearActiveConversation() {
        cancelStream()
        dispatch(ChatClearActiveConversationCommand())
    }

    func reopenConversation(_ conversation: SidePanelConversation) async {
        cancelStream()
        dispatch(ChatReopenConversationCommand(conversation: conversation))
        let restored = (try? await history.loadMessages(conversation.id)) ?? []
        dispatch(ChatMessagesRestoredCommand(messages: restored))
    }

    func renameActiveConversation(id: UUID, title: String) {
        guard state.conversation?.id == id else { return }
        state.conversation?.title = title
    }

    // MARK: - Send / Retry

    func sendMessage(speedMode: HomeComposerSpeedMode? = nil) async {
        let content = state.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let preference = providerPreference.preference()
        guard !content.isEmpty,
              !state.isSending,
              let modelID = preference.modelID else {
            return
        }

        beginTurn(draft: "")
        let timestamp = now()
        let userMessage = ChatMessage.text(
            id: makeID(),
            role: .user,
            content: content,
            timestamp: timestamp
        )
        state.messages.append(userMessage)

        if state.conversation == nil {
            state.conversation = SidePanelConversation(
                id: makeID(),
                title: Self.conversationTitle(for: content),
                createdAt: timestamp,
                updatedAt: timestamp
            )
        } else {
            state.conversation?.title = Self.conversationTitle(for: content)
            state.conversation?.updatedAt = timestamp
        }

        if let conversation = state.conversation {
            let history = history
            Task {
                try? await history.saveConversation(conversation)
                try? await history.appendMessage(conversation.id, userMessage)
            }
        }

        startStream(modelID: modelID, preference: preference, speedMode: speedMode)
        await streamTask?.value
    }

    func retry(speedMode: HomeComposerSpeedMode? = nil) async {
        let preference = providerPreference.preference()
        guard !state.isSending,
              let modelID = preference.modelID,
              !state.messages.isEmpty else {
            return
        }

        beginTurn(draft: nil)
        startStream(modelID: modelID, preference: preference, speedMode: speedMode)
        await streamTask?.value
    }

    // MARK: - Streaming

    private func beginTurn(draft: String?) {
        if let draft { state.draftMessage = draft }
        state.isSending = true
        state.streamingStatus = .running
        state.currentPartialText = ""
        state.currentPartialThinking = ""
        state.streamErrorMessage = nil
        state.streamingThinkingID = nil
        state.streamingAnswerID = nil
    }

    private func startStream(
        modelID: String,
        preference: SidePanelProviderPreference,
        speedMode: HomeComposerSpeedMode? = nil
    ) {
        cancelStream()

        let conversationID = state.conversation?.id ?? makeID()
        let request = ChatRequest(
            conversationID: conversationID,
            messages: state.messages,
            provider: SidePanelProviderAPI.resolve(id: preference.providerID),
            modelID: modelID,
            reasoningEffort: preference.reasoningModel.effort,
            speedMode: speedMode
        )

        let stream = streaming.stream(request)
        streamTask = Task { [weak self] in
            for await event in stream {
                guard let self, !Task.isCancelled else { return }
                await self.handleStreamingEvent(event)
            }
        }
    }

    private func handleStreamingEvent(_ event: ChatStreamingEvent) async {
        switch event {
        case let .thinkingDelta(delta):
            state.currentPartialThinking += delta
            state.streamingStatus = .running

            let trimmedThinking = state.currentPartialThinking.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedThinking.isEmpty else { return }

            if let thinkingID = state.streamingThinkingID,
               let index = state.messages.firstIndex(where: { $0.id == thinkingID }),
               case .thinking(var thinkingMessage) = state.messages[index] {
                thinkingMessage.content = state.currentPartialThinking
                thinkingMessage.isComplete = false
                state.messages[index] = .thinking(thinkingMessage)
            } else {
                let newID = makeID()
                state.streamingThinkingID = newID
                state.messages.append(
                    .thinking(
                        id: newID,
                        content: state.currentPartialThinking,
                        isComplete: false,
                        timestamp: now()
                    )
                )
            }

        case let .textDelta(delta):
            state.currentPartialText += delta
            state.streamingStatus = .running

            if let answerID = state.streamingAnswerID,
               let index = state.messages.firstIndex(where: { $0.id == answerID }),
               case .text(var textMessage) = state.messages[index] {
                textMessage.content = state.currentPartialText
                textMessage.isComplete = false
                state.messages[index] = .text(textMessage)
            } else {
                let newID = makeID()
                state.streamingAnswerID = newID
                state.messages.append(
                    .text(
                        id: newID,
                        role: .assistant,
                        content: state.currentPartialText,
                        isComplete: false,
                        timestamp: now()
                    )
                )
            }

        case .done:
            if let thinkingID = state.streamingThinkingID,
               let index = state.messages.firstIndex(where: { $0.id == thinkingID }),
               case .thinking(var thinkingMessage) = state.messages[index] {
                thinkingMessage.isComplete = true
                state.messages[index] = .thinking(thinkingMessage)
            }
            if let answerID = state.streamingAnswerID,
               let index = state.messages.firstIndex(where: { $0.id == answerID }),
               case .text(var textMessage) = state.messages[index] {
                textMessage.isComplete = true
                state.messages[index] = .text(textMessage)
            }

            let conversationID = state.conversation?.id
            let updatedConversation = state.conversation
            let finalizedMessages: [ChatMessage] = [
                state.streamingThinkingID,
                state.streamingAnswerID
            ]
            .compactMap { id in
                guard let id else { return nil }
                return state.messages.first(where: { $0.id == id })
            }

            state.currentPartialText = ""
            state.currentPartialThinking = ""
            state.streamingThinkingID = nil
            state.streamingAnswerID = nil
            state.streamingStatus = .done
            state.isSending = false

            if let conversationID {
                let history = history
                Task {
                    if let updatedConversation {
                        try? await history.saveConversation(updatedConversation)
                    }
                    for message in finalizedMessages {
                        try? await history.appendMessage(conversationID, message)
                    }
                }
            }

        case let .error(streamError):
            state.streamingStatus = .failed
            state.streamErrorMessage = streamError.message
            state.isSending = false
            state.currentPartialText = ""
            state.currentPartialThinking = ""
            state.streamingThinkingID = nil
            state.streamingAnswerID = nil
        }
    }

    private func cancelStream() {
        streamTask?.cancel()
        streamTask = nil
    }

    private static func conversationTitle(for content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "New chat" }
        if trimmed.count <= 40 { return trimmed }
        return String(trimmed.prefix(40)) + "…"
    }
}
