import Foundation

/// Summarizes messages using the active provider stream (model-agnostic).
nonisolated struct SettingsContextCompactionStreamSummarizer: SettingsContextCompactionSummarizing {
    let streaming: ChatStreamingClient
    let providerPreference: any ProviderPreferenceStore

    func summarize(prompt: String) async throws -> String {
        let preference = providerPreference.preference()
        guard let modelID = preference.modelID else {
            throw SettingsContextCompactionError.missingModel
        }

        let request = ChatRequest(
            atomID: UUID(),
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

    func summarize(messages: [ChatMessage]) async throws -> String {
        let transcript = messages.map { message in
            "\(message.role.rawValue): \(Self.messageText(message))"
        }.joined(separator: "\n")

        let prompt = """
        Summarize the following conversation for continuation. Preserve goals, decisions, facts, and open tasks. Be concise.

        \(transcript)
        """
        return try await summarize(prompt: prompt)
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

/// Thin client injected into Chat for automatic, manual, and overflow compaction.
nonisolated struct SettingsContextCompactionClient: Sendable {
    var compactIfNeeded: @Sendable (
        _ messages: [ChatMessage],
        _ sessionEntries: [AtomSessionEntry],
        _ leafEntryID: UUID?,
        _ contextLength: Int
    ) async throws -> SettingsContextCompactionOutcome

    var compactManually: @Sendable (
        _ messages: [ChatMessage],
        _ sessionEntries: [AtomSessionEntry],
        _ leafEntryID: UUID?,
        _ contextLength: Int
    ) async throws -> SettingsContextCompactionOutcome

    var compactForOverflow: @Sendable (
        _ messages: [ChatMessage],
        _ sessionEntries: [AtomSessionEntry],
        _ leafEntryID: UUID?,
        _ contextLength: Int
    ) async throws -> SettingsContextCompactionOutcome

    init(
        compactIfNeeded: @escaping @Sendable (
            [ChatMessage],
            [AtomSessionEntry],
            UUID?,
            Int
        ) async throws -> SettingsContextCompactionOutcome,
        compactManually: @escaping @Sendable (
            [ChatMessage],
            [AtomSessionEntry],
            UUID?,
            Int
        ) async throws -> SettingsContextCompactionOutcome,
        compactForOverflow: @escaping @Sendable (
            [ChatMessage],
            [AtomSessionEntry],
            UUID?,
            Int
        ) async throws -> SettingsContextCompactionOutcome
    ) {
        self.compactIfNeeded = compactIfNeeded
        self.compactManually = compactManually
        self.compactForOverflow = compactForOverflow
    }

    static let disabled = SettingsContextCompactionClient(
        compactIfNeeded: { messages, _, _, _ in .unchanged(messages) },
        compactManually: { messages, _, _, _ in .unchanged(messages) },
        compactForOverflow: { messages, _, _, _ in .unchanged(messages) }
    )

    static func live(
        engine: SettingsContextCompactionEngine,
        preferenceStore: any SettingsContextCompactionPreferenceStore
    ) -> SettingsContextCompactionClient {
        SettingsContextCompactionClient(
            compactIfNeeded: { messages, sessionEntries, leafEntryID, contextLength in
                let preference = preferenceStore.preference()
                return try await engine.compactIfNeeded(
                    messages: messages,
                    sessionEntries: sessionEntries,
                    leafEntryID: leafEntryID,
                    contextLength: contextLength,
                    preference: preference
                )
            },
            compactManually: { messages, sessionEntries, leafEntryID, contextLength in
                let preference = preferenceStore.preference()
                return try await engine.compactManually(
                    messages: messages,
                    sessionEntries: sessionEntries,
                    leafEntryID: leafEntryID,
                    contextLength: contextLength,
                    preference: preference
                )
            },
            compactForOverflow: { messages, sessionEntries, leafEntryID, contextLength in
                let preference = preferenceStore.preference()
                return try await engine.compactForOverflow(
                    messages: messages,
                    sessionEntries: sessionEntries,
                    leafEntryID: leafEntryID,
                    contextLength: contextLength,
                    preference: preference
                )
            }
        )
    }
}
