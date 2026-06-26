import Foundation

/// Strategy for reducing message history when context usage exceeds a threshold.
nonisolated protocol SettingsContextCompactionStrategizing: Sendable {
    func compact(
        messages: [ChatMessage],
        contextLength: Int,
        thresholdPercent: Int,
        minRecentMessages: Int
    ) async throws -> [ChatMessage]
}

/// Model-agnostic summarization boundary for compaction.
nonisolated protocol SettingsContextCompactionSummarizing: Sendable {
    func summarize(messages: [ChatMessage]) async throws -> String
}

/// Drops oldest non-system messages until usage falls below the threshold.
nonisolated struct SettingsContextCompactionTrimStrategy: SettingsContextCompactionStrategizing {
    func compact(
        messages: [ChatMessage],
        contextLength: Int,
        thresholdPercent: Int,
        minRecentMessages: Int
    ) async throws -> [ChatMessage] {
        guard contextLength > 0, messages.count > minRecentMessages else { return messages }

        var working = messages
        let targetFraction = Double(thresholdPercent) / 100.0 * 0.85

        while working.count > minRecentMessages,
              usageFraction(messages: working, contextLength: contextLength) >= targetFraction {
            guard let dropIndex = indexOfOldestDroppableMessage(in: working, minRecentMessages: minRecentMessages) else {
                break
            }
            working.remove(at: dropIndex)
        }

        return working
    }

    private func indexOfOldestDroppableMessage(in messages: [ChatMessage], minRecentMessages: Int) -> Int? {
        let protectedTailStart = max(0, messages.count - minRecentMessages)
        for index in 0..<protectedTailStart where !isLeadingSystemMessage(messages[index], at: index) {
            return index
        }
        return nil
    }

    private func isLeadingSystemMessage(_ message: ChatMessage, at index: Int) -> Bool {
        index == 0 && message.role == .system
    }

    private func usageFraction(messages: [ChatMessage], contextLength: Int) -> Double {
        ContextWindowEstimator.estimate(
            messages: messages,
            draft: nil,
            contextLength: contextLength
        ).fractionUsed
    }
}

/// Summarizes the oldest block into a single system message before the recent tail.
nonisolated struct SettingsContextCompactionSummarizeStrategy: SettingsContextCompactionStrategizing {
    let summarizer: any SettingsContextCompactionSummarizing

    func compact(
        messages: [ChatMessage],
        contextLength: Int,
        thresholdPercent: Int,
        minRecentMessages: Int
    ) async throws -> [ChatMessage] {
        guard messages.count > minRecentMessages else { return messages }

        let splitIndex = messages.count - minRecentMessages
        let leadingSystem = messages.first?.role == .system ? messages[0] : nil
        let compactStart = leadingSystem == nil ? 0 : 1
        let compactEnd = splitIndex
        guard compactEnd > compactStart else { return messages }

        let toSummarize = Array(messages[compactStart..<compactEnd])
        guard !toSummarize.isEmpty else { return messages }

        let summaryText = try await summarizer.summarize(messages: toSummarize)
        let summaryMessage = ChatMessage.system(
            id: UUID(),
            content: "[Conversation summary]\n\(summaryText)",
            timestamp: toSummarize.last?.timestamp ?? Date()
        )

        var result: [ChatMessage] = []
        if let leadingSystem { result.append(leadingSystem) }
        result.append(summaryMessage)
        result.append(contentsOf: messages[splitIndex...])
        return result
    }
}

/// Facade coordinating trim-then-summarize compaction.
nonisolated struct SettingsContextCompactionEngine: Sendable {
    let trimStrategy: any SettingsContextCompactionStrategizing
    let summarizeStrategy: any SettingsContextCompactionStrategizing

    init(
        trimStrategy: any SettingsContextCompactionStrategizing = SettingsContextCompactionTrimStrategy(),
        summarizeStrategy: (any SettingsContextCompactionStrategizing)? = nil,
        summarizer: (any SettingsContextCompactionSummarizing)? = nil
    ) {
        self.trimStrategy = trimStrategy
        if let summarizeStrategy {
            self.summarizeStrategy = summarizeStrategy
        } else if let summarizer {
            self.summarizeStrategy = SettingsContextCompactionSummarizeStrategy(summarizer: summarizer)
        } else {
            self.summarizeStrategy = SettingsContextCompactionTrimStrategy()
        }
    }

    func shouldCompact(
        messages: [ChatMessage],
        contextLength: Int,
        preference: SettingsContextCompactionPreference
    ) -> Bool {
        guard preference.isEnabled, contextLength > 0, !messages.isEmpty else { return false }
        let usage = ContextWindowEstimator.estimate(
            messages: messages,
            draft: nil,
            contextLength: contextLength
        )
        let threshold = Double(preference.triggerThresholdPercent) / 100.0
        return usage.fractionUsed >= threshold
    }

    func compactIfNeeded(
        messages: [ChatMessage],
        contextLength: Int,
        preference: SettingsContextCompactionPreference
    ) async throws -> [ChatMessage] {
        guard shouldCompact(messages: messages, contextLength: contextLength, preference: preference) else {
            return messages
        }

        let trimmed = try await trimStrategy.compact(
            messages: messages,
            contextLength: contextLength,
            thresholdPercent: preference.triggerThresholdPercent,
            minRecentMessages: preference.minRecentMessages
        )

        if !shouldCompact(messages: trimmed, contextLength: contextLength, preference: preference) {
            return trimmed
        }

        return try await summarizeStrategy.compact(
            messages: messages,
            contextLength: contextLength,
            thresholdPercent: preference.triggerThresholdPercent,
            minRecentMessages: preference.minRecentMessages
        )
    }
}
