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
    private let contextCompaction: SettingsContextCompactionClient
    private let contextLengthResolver: () -> Int
    private let invoker = ChatCommandInvoker()
    private var streamTask: Task<Void, Never>?
    private var lastProviderSortBy: String?
    private var lastReasoningEffort: String?
    private var accumulatedPartialText = ""
    private var accumulatedPartialThinking = ""
    private var accumulatedOutputStreamDelta = ""
    private var streamingFlushTask: Task<Void, Never>?
    private let makeID: () -> UUID
    private let now: () -> Date

    init(
        state: ChatFlowState = ChatFlowState(),
        streaming: ChatStreamingClient = .preview,
        history: ChatHistoryClient = .preview,
        providerPreference: any SidePanelProviderPreferenceStore = SidePanelInMemoryProviderPreferenceStore(),
        contextCompaction: SettingsContextCompactionClient = .disabled,
        contextLengthResolver: @escaping () -> Int = { 0 },
        makeID: @escaping () -> UUID = UUID.init,
        now: @escaping () -> Date = Date.init
    ) {
        self.state = state
        self.streaming = streaming
        self.history = history
        self.providerPreference = providerPreference
        self.contextCompaction = contextCompaction
        self.contextLengthResolver = contextLengthResolver
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

    func addDraftAttachment(_ attachment: ChatMessageAttachment) {
        dispatch(ChatDraftAttachmentAddedCommand(attachment: attachment))
    }

    func removeDraftAttachment(id: UUID) {
        if let attachment = state.draftAttachments.first(where: { $0.id == id }) {
            ChatAttachmentStore.remove(at: attachment.localPath)
        }
        dispatch(ChatDraftAttachmentRemovedCommand(id: id))
    }

    func clearDraftAttachments() {
        for attachment in state.draftAttachments {
            ChatAttachmentStore.remove(at: attachment.localPath)
        }
        dispatch(ChatDraftAttachmentsClearedCommand())
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

    private struct SendTurnSnapshot {
        let messages: [ChatMessage]
        let conversation: SidePanelConversation?
        let draftMessage: String
        let draftAttachments: [ChatMessageAttachment]
    }

    func sendMessage(providerSortBy: String? = nil, reasoningEffort: String? = nil) async {
        let visibleText = state.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachments = state.draftAttachments
        let preference = providerPreference.preference()
        guard (!visibleText.isEmpty || !attachments.isEmpty),
              !state.isSending,
              let modelID = preference.modelID else {
            return
        }

        let snapshot = SendTurnSnapshot(
            messages: state.messages,
            conversation: state.conversation,
            draftMessage: state.draftMessage,
            draftAttachments: attachments
        )

        let timestamp = now()
        let modelContent = ChatModelInputBuilder.modelContent(
            visibleText: visibleText,
            attachments: attachments
        )
        let userMessage = ChatMessage.text(
            id: makeID(),
            role: .user,
            content: visibleText,
            timestamp: timestamp,
            attachments: attachments,
            modelContent: modelContent
        )
        state.draftMessage = ""
        state.draftAttachments = []
        state.messages.append(userMessage)

        if state.conversation == nil {
            state.conversation = SidePanelConversation(
                id: makeID(),
                title: Self.conversationTitle(visibleText: visibleText, attachments: attachments),
                createdAt: timestamp,
                updatedAt: timestamp
            )
        } else {
            state.conversation?.title = Self.conversationTitle(
                visibleText: visibleText,
                attachments: attachments
            )
            state.conversation?.updatedAt = timestamp
        }

        guard await prepareTurnForStreaming(
            errorMessage: "Could not prepare conversation for sending."
        ) else {
            restoreSendTurn(snapshot)
            return
        }

        beginTurn(draft: nil)
        startStream(
            modelID: modelID,
            preference: preference,
            providerSortBy: providerSortBy,
            reasoningEffort: reasoningEffort
        )
        await streamTask?.value
    }

    func retry(providerSortBy: String? = nil, reasoningEffort: String? = nil) async {
        let preference = providerPreference.preference()
        guard !state.isSending,
              let modelID = preference.modelID,
              !state.messages.isEmpty else {
            return
        }

        guard await prepareTurnForStreaming(
            errorMessage: "Could not compact conversation context."
        ) else {
            state.streamingStatus = .failed
            state.isSending = false
            return
        }

        beginTurn(draft: nil)
        startStream(
            modelID: modelID,
            preference: preference,
            providerSortBy: providerSortBy ?? lastProviderSortBy,
            reasoningEffort: reasoningEffort ?? lastReasoningEffort
        )
        await streamTask?.value
    }

    // MARK: - Streaming

    private enum StreamingCoalescingPolicy {
        static let defaultFlushDelayNanoseconds: UInt64 = 80_000_000
        static let mediumFlushDelayNanoseconds: UInt64 = 120_000_000
        static let largeFlushDelayNanoseconds: UInt64 = 200_000_000
        static let mediumTextByteCount = 8_000
        static let largeTextByteCount = 32_000
    }

    private func streamingFlushDelayNanoseconds() -> UInt64 {
        let byteCount = max(
            accumulatedPartialText.utf8.count,
            accumulatedPartialThinking.utf8.count,
            accumulatedOutputStreamDelta.utf8.count
        )
        if byteCount >= StreamingCoalescingPolicy.largeTextByteCount {
            return StreamingCoalescingPolicy.largeFlushDelayNanoseconds
        }
        if byteCount >= StreamingCoalescingPolicy.mediumTextByteCount {
            return StreamingCoalescingPolicy.mediumFlushDelayNanoseconds
        }
        return StreamingCoalescingPolicy.defaultFlushDelayNanoseconds
    }

    private func beginTurn(draft: String?) {
        if let draft { state.draftMessage = draft }
        state.isSending = true
        state.streamingStatus = .running
        resetStreamingBuffers()
        state.streamErrorMessage = nil
        state.streamingThinkingID = nil
        state.streamingAnswerID = nil
        state.streamingOutputStreamID = nil
        state.streamingRevision = 0
    }

    private func resetStreamingBuffers() {
        cancelStreamingFlush()
        accumulatedPartialText = ""
        accumulatedPartialThinking = ""
        accumulatedOutputStreamDelta = ""
        state.currentPartialText = ""
        state.currentPartialThinking = ""
    }

    private func cancelStreamingFlush() {
        streamingFlushTask?.cancel()
        streamingFlushTask = nil
    }

    private func scheduleStreamingFlush() {
        guard streamingFlushTask == nil else { return }
        streamingFlushTask = Task { [weak self] in
            guard let self else { return }
            let delay = self.streamingFlushDelayNanoseconds()
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            self.streamingFlushTask = nil
            self.applyPendingStreamingUI()
        }
    }

    private func flushStreamingNow() {
        cancelStreamingFlush()
        applyPendingStreamingUI()
    }

    private func applyPendingStreamingUI() {
        var didChange = false

        let trimmedThinking = accumulatedPartialThinking.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedThinking.isEmpty {
            if let thinkingID = state.streamingThinkingID,
               let index = state.messages.firstIndex(where: { $0.id == thinkingID }),
               case .thinking(var thinkingMessage) = state.messages[index] {
                thinkingMessage.content = accumulatedPartialThinking
                thinkingMessage.isComplete = false
                state.messages[index] = .thinking(thinkingMessage)
            } else {
                let newID = makeID()
                state.streamingThinkingID = newID
                state.messages.append(
                    .thinking(
                        id: newID,
                        content: accumulatedPartialThinking,
                        isComplete: false,
                        timestamp: now()
                    )
                )
            }
            didChange = true
        }

        if !accumulatedPartialText.isEmpty {
            if let answerID = state.streamingAnswerID,
               let index = state.messages.firstIndex(where: { $0.id == answerID }),
               case .text(var textMessage) = state.messages[index] {
                textMessage.content = accumulatedPartialText
                textMessage.isComplete = false
                state.messages[index] = .text(textMessage)
            } else {
                let newID = makeID()
                state.streamingAnswerID = newID
                state.messages.append(
                    .text(
                        id: newID,
                        role: .assistant,
                        content: accumulatedPartialText,
                        isComplete: false,
                        timestamp: now()
                    )
                )
            }
            didChange = true
        }

        if !accumulatedOutputStreamDelta.isEmpty {
            if let outputStreamID = state.streamingOutputStreamID,
               let index = state.messages.firstIndex(where: { $0.id == outputStreamID }),
               case .outputStream(var outputStreamMessage) = state.messages[index] {
                outputStreamMessage.detail.appendOutput(accumulatedOutputStreamDelta)
                outputStreamMessage.isComplete = false
                state.messages[index] = .outputStream(outputStreamMessage)
            }
            accumulatedOutputStreamDelta = ""
            didChange = true
        }

        guard didChange else { return }
        state.currentPartialText = accumulatedPartialText
        state.currentPartialThinking = accumulatedPartialThinking
        state.streamingRevision &+= 1
    }

    private func startStream(
        modelID: String,
        preference: SidePanelProviderPreference,
        providerSortBy: String? = nil,
        reasoningEffort: String? = nil
    ) {
        cancelStream()
        lastProviderSortBy = providerSortBy
        lastReasoningEffort = reasoningEffort

        let conversationID = state.conversation?.id ?? makeID()
        let request = ChatRequest(
            conversationID: conversationID,
            messages: state.messages,
            providerID: preference.providerID ?? ProviderDescriptor.openRouter.id,
            modelID: modelID,
            reasoningEffort: reasoningEffort,
            providerSortBy: providerSortBy
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
            accumulatedPartialThinking += delta
            state.streamingStatus = .running
            scheduleStreamingFlush()

        case let .textDelta(delta):
            accumulatedPartialText += delta
            state.streamingStatus = .running
            scheduleStreamingFlush()

        case let .outputStreamBegan(command, cwd):
            flushStreamingNow()
            beginOutputStream(command: command, cwd: cwd)

        case let .outputStreamDelta(delta):
            accumulatedOutputStreamDelta += delta
            state.streamingStatus = .running
            scheduleStreamingFlush()

        case let .outputStreamEnded(status, exitCode, durationMs):
            flushStreamingNow()
            finalizeActiveOutputStream(
                status: status,
                exitCode: exitCode,
                durationMs: durationMs
            )

        case .done:
            flushStreamingNow()
            if let thinkingID = state.streamingThinkingID,
               let index = state.messages.firstIndex(where: { $0.id == thinkingID }),
               case .thinking(var thinkingMessage) = state.messages[index] {
                thinkingMessage.isComplete = true
                state.messages[index] = .thinking(thinkingMessage)
            }
            if let answerID = state.streamingAnswerID,
               let index = state.messages.firstIndex(where: { $0.id == answerID }),
               case .text(var textMessage) = state.messages[index] {
                textMessage.content = ChatAssistantContentNormalizer.displayText(from: textMessage.content)
                textMessage.isComplete = true
                state.messages[index] = .text(textMessage)
            }
            if state.streamingOutputStreamID != nil {
                finalizeActiveOutputStream(status: .completed, exitCode: nil, durationMs: nil)
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
            accumulatedPartialText = ""
            accumulatedPartialThinking = ""
            accumulatedOutputStreamDelta = ""
            state.streamingThinkingID = nil
            state.streamingAnswerID = nil
            state.streamingOutputStreamID = nil
            state.streamingStatus = .done
            state.isSending = false
            state.streamingRevision &+= 1

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
            flushStreamingNow()
            if state.streamingOutputStreamID != nil {
                finalizeActiveOutputStream(status: .failed, exitCode: nil, durationMs: nil)
            }
            state.streamingStatus = .failed
            state.streamErrorMessage = streamError.message
            state.isSending = false
            resetStreamingBuffers()
            state.streamingThinkingID = nil
            state.streamingAnswerID = nil
            state.streamingOutputStreamID = nil
            state.streamingRevision &+= 1
        }
    }

    private func beginOutputStream(command: String, cwd: String?) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if state.streamingOutputStreamID != nil {
            finalizeActiveOutputStream(status: .completed, exitCode: nil, durationMs: nil)
        }

        let newID = makeID()
        state.streamingOutputStreamID = newID
        state.messages.append(
            .outputStream(
                id: newID,
                command: trimmed,
                detail: ChatOutputStreamDetail(status: .running, cwd: cwd),
                isComplete: false,
                timestamp: now()
            )
        )
        state.streamingRevision &+= 1
    }

    private func finalizeActiveOutputStream(
        status: ChatOutputStreamStatus,
        exitCode: Int?,
        durationMs: Int?
    ) {
        guard let outputStreamID = state.streamingOutputStreamID,
              let index = state.messages.firstIndex(where: { $0.id == outputStreamID }),
              case .outputStream(var outputStreamMessage) = state.messages[index] else {
            state.streamingOutputStreamID = nil
            return
        }

        outputStreamMessage.detail.status = status
        outputStreamMessage.detail.exitCode = exitCode ?? outputStreamMessage.detail.exitCode
        outputStreamMessage.detail.durationMs = durationMs ?? outputStreamMessage.detail.durationMs
        outputStreamMessage.isComplete = true
        state.messages[index] = .outputStream(outputStreamMessage)
        state.streamingOutputStreamID = nil
        state.streamingRevision &+= 1

        if let conversationID = state.conversation?.id {
            let message = state.messages[index]
            let history = history
            Task {
                try? await history.appendMessage(conversationID, message)
            }
        }
    }

    private func cancelStream() {
        flushStreamingNow()
        if state.streamingOutputStreamID != nil {
            finalizeActiveOutputStream(status: .failed, exitCode: nil, durationMs: nil)
        }
        cancelStreamingFlush()
        streamTask?.cancel()
        streamTask = nil
    }

    private func restoreSendTurn(_ snapshot: SendTurnSnapshot) {
        state.messages = snapshot.messages
        state.conversation = snapshot.conversation
        state.draftMessage = snapshot.draftMessage
        state.draftAttachments = snapshot.draftAttachments
        state.streamingStatus = .failed
        state.isSending = false
    }

    private func prepareTurnForStreaming(errorMessage: String) async -> Bool {
        let messagesBeforeCompaction = state.messages
        do {
            try await applyContextCompactionIfNeeded()
            try await persistConversationMessages()
            return true
        } catch {
            state.messages = messagesBeforeCompaction
            state.streamErrorMessage = errorMessage
            return false
        }
    }

    private func persistConversationMessages() async throws {
        guard let conversation = state.conversation else { return }
        try await history.saveConversation(conversation)
        try await history.replaceMessages(conversation.id, state.messages)
    }

    private func applyContextCompactionIfNeeded() async throws {
        let contextLength = contextLengthResolver()
        guard contextLength > 0 else { return }

        let compacted = try await contextCompaction.compactIfNeeded(state.messages, contextLength)
        if compacted != state.messages {
            state.messages = compacted
        }
    }

    private static func conversationTitle(
        visibleText: String,
        attachments: [ChatMessageAttachment]
    ) -> String {
        let trimmed = visibleText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            if trimmed.count <= 40 { return trimmed }
            return String(trimmed.prefix(40)) + "…"
        }
        if let firstAttachment = attachments.first {
            return firstAttachment.filename
        }
        return "New chat"
    }
}
