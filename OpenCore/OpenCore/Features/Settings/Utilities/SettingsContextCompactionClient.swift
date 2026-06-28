import Foundation

/// Summarizes messages using the active provider stream (model-agnostic).
nonisolated struct SettingsContextCompactionStreamSummarizer: SettingsContextCompactionSummarizing {
    let streaming: ChatStreamingClient
    let providerPreference: any SidePanelProviderPreferenceStore

    func summarize(messages: [ChatMessage]) async throws -> String {
        let preference = providerPreference.preference()
        guard let modelID = preference.modelID else {
            throw SettingsContextCompactionError.missingModel
        }

        let prompt = Self.summarizationPrompt(for: messages)
        let request = ChatRequest(
            conversationID: UUID(),
            messages: [.text(role: .user, content: prompt, timestamp: Date())],
            providerID: preference.providerID ?? ProviderDescriptor.openRouter.id,
            modelID: modelID,
            reasoningEffort: nil,
            providerSortBy: nil
        )

        var summary = ""
        for await event in streaming.stream(request) {
            switch event {
            case let .textDelta(delta):
                summary += delta
            case .thinkingDelta, .outputStreamBegan, .outputStreamDelta, .outputStreamEnded:
                continue
            case .done:
                return summary.trimmingCharacters(in: .whitespacesAndNewlines)
            case let .error(streamError):
                throw SettingsContextCompactionError.summarizationFailed(streamError.message)
            }
        }

        return summary.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func summarizationPrompt(for messages: [ChatMessage]) -> String {
        let transcript = messages.map { message in
            "\(message.role.rawValue): \(messageText(message))"
        }.joined(separator: "\n")

        return """
        Summarize the following conversation for continuation. Preserve goals, decisions, facts, and open tasks. Be concise.

        \(transcript)
        """
    }

    private static func messageText(_ message: ChatMessage) -> String {
        switch message {
        case let .text(text): return text.content
        case let .thinking(thinking): return thinking.content
        case let .system(system): return system.content
        case let .outputStream(outputStream):
            guard outputStream.isComplete else { return "" }
            return outputStream.command + "\n" + outputStream.detail.outputTail
        }
    }
}

enum SettingsContextCompactionError: Error, Equatable {
    case missingModel
    case summarizationFailed(String)
}

/// Thin client injected into Chat for automatic compaction before send.
nonisolated struct SettingsContextCompactionClient: Sendable {
    var compactIfNeeded: @Sendable (
        _ messages: [ChatMessage],
        _ contextLength: Int
    ) async throws -> [ChatMessage]

    init(
        compactIfNeeded: @escaping @Sendable ([ChatMessage], Int) async throws -> [ChatMessage]
    ) {
        self.compactIfNeeded = compactIfNeeded
    }

    static let disabled = SettingsContextCompactionClient { messages, _ in messages }

    static func live(
        engine: SettingsContextCompactionEngine,
        preferenceStore: any SettingsContextCompactionPreferenceStore
    ) -> SettingsContextCompactionClient {
        SettingsContextCompactionClient { messages, contextLength in
            let preference = preferenceStore.preference()
            return try await engine.compactIfNeeded(
                messages: messages,
                contextLength: contextLength,
                preference: preference
            )
        }
    }
}
