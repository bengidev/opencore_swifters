import Foundation

/// Strategy for reducing message history when session-tree compaction is unavailable.
nonisolated protocol SettingsContextCompactionStrategizing: Sendable {
    func compact(
        messages: [ChatMessage],
        contextLength: Int,
        minRecentMessages: Int
    ) async throws -> [ChatMessage]
}

/// Model-agnostic summarization boundary for compaction.
nonisolated protocol SettingsContextCompactionSummarizing: Sendable {
    func summarize(messages: [ChatMessage]) async throws -> String
    func summarize(prompt: String) async throws -> String
}

extension SettingsContextCompactionSummarizing {
    func summarize(prompt: String) async throws -> String {
        try await summarize(messages: [.text(role: .user, content: prompt)])
    }
}

/// Drops oldest non-system messages until usage falls below the Pi reserve threshold.
nonisolated struct SettingsContextCompactionTrimStrategy: SettingsContextCompactionStrategizing {
    func compact(
        messages: [ChatMessage],
        contextLength: Int,
        minRecentMessages: Int
    ) async throws -> [ChatMessage] {
        guard contextLength > 0, messages.count > minRecentMessages else { return messages }

        var working = messages
        let reserveTokens = SettingsContextCompactionPreference().reserveTokens
        let targetTokens = max(0, contextLength - reserveTokens)

        while working.count > minRecentMessages + 1,
              ContextTokenCounter.countTokens(for: working) > targetTokens {
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
}

/// Facade coordinating Pi-style append-only compaction checkpoints.
nonisolated struct SettingsContextCompactionEngine: Sendable {
    let trimStrategy: any SettingsContextCompactionStrategizing
    let summarizer: any SettingsContextCompactionSummarizing

    init(
        trimStrategy: any SettingsContextCompactionStrategizing = SettingsContextCompactionTrimStrategy(),
        summarizer: any SettingsContextCompactionSummarizing
    ) {
        self.trimStrategy = trimStrategy
        self.summarizer = summarizer
    }

    func shouldCompact(
        messages: [ChatMessage],
        contextLength: Int,
        preference: SettingsContextCompactionPreference
    ) -> Bool {
        guard preference.isEnabled, contextLength > 0, !messages.isEmpty else { return false }
        return ContextWindowEstimator.shouldCompact(
            messages: messages,
            draft: nil,
            contextLength: contextLength,
            reserveTokens: preference.reserveTokens
        )
    }

    func compactIfNeeded(
        messages: [ChatMessage],
        sessionEntries: [AtomSessionEntry],
        leafEntryID: UUID?,
        contextLength: Int,
        preference: SettingsContextCompactionPreference
    ) async throws -> SettingsContextCompactionOutcome {
        guard shouldCompact(messages: messages, contextLength: contextLength, preference: preference) else {
            return .unchanged(messages)
        }

        return try await performCompaction(
            messages: messages,
            sessionEntries: sessionEntries,
            leafEntryID: leafEntryID,
            contextLength: contextLength,
            preference: preference,
            keepRecentTokens: preference.keepRecentTokens
        )
    }

    func compactManually(
        messages: [ChatMessage],
        sessionEntries: [AtomSessionEntry],
        leafEntryID: UUID?,
        contextLength: Int,
        preference: SettingsContextCompactionPreference
    ) async throws -> SettingsContextCompactionOutcome {
        try await performCompaction(
            messages: messages,
            sessionEntries: sessionEntries,
            leafEntryID: leafEntryID,
            contextLength: contextLength,
            preference: preference,
            keepRecentTokens: 0
        )
    }

    func compactForOverflow(
        messages: [ChatMessage],
        sessionEntries: [AtomSessionEntry],
        leafEntryID: UUID?,
        contextLength: Int,
        preference: SettingsContextCompactionPreference
    ) async throws -> SettingsContextCompactionOutcome {
        try await performCompaction(
            messages: messages,
            sessionEntries: sessionEntries,
            leafEntryID: leafEntryID,
            contextLength: contextLength,
            preference: preference,
            keepRecentTokens: preference.keepRecentTokens
        )
    }

    private func performCompaction(
        messages: [ChatMessage],
        sessionEntries: [AtomSessionEntry],
        leafEntryID: UUID?,
        contextLength: Int,
        preference: SettingsContextCompactionPreference,
        keepRecentTokens: Int
    ) async throws -> SettingsContextCompactionOutcome {
        let tokensBefore = ContextTokenCounter.countTokens(for: messages)
        let plannerSettings = AtomSessionCompactionPlanner.Settings(
            keepRecentTokens: keepRecentTokens
        )
        guard let preparation = AtomSessionCompactionPlanner.prepareCompaction(
            entries: sessionEntries,
            leafID: leafEntryID,
            settings: plannerSettings,
            tokensBefore: tokensBefore
        ) else {
            guard contextLength > 0 else { return .unchanged(messages) }
            let trimmed = try await trimStrategy.compact(
                messages: messages,
                contextLength: contextLength,
                minRecentMessages: preference.minRecentMessages
            )
            guard trimmed != messages else { return .unchanged(messages) }
            return SettingsContextCompactionOutcome(projectedMessages: trimmed, checkpoint: nil)
        }

        let summaryBody = try await summarizePreparedSegment(preparation)

        let checkpoint = AtomCompactionCheckpoint(
            summary: summaryBody,
            firstKeptEntryID: preparation.firstKeptEntryID,
            tokensBefore: tokensBefore,
            readFiles: preparation.readFiles,
            modifiedFiles: preparation.modifiedFiles
        )

        var syntheticEntries = sessionEntries
        let compactionEntry = AtomSessionEntry.compactionEntry(
            id: UUID(),
            atomID: sessionEntries.first?.atomID ?? UUID(),
            parentID: leafEntryID,
            checkpoint: checkpoint,
            timestamp: Date()
        )
        syntheticEntries.append(compactionEntry)

        let projected = AtomSessionContextBuilder.buildModelMessages(
            entries: syntheticEntries,
            leafID: compactionEntry.id
        )

        return SettingsContextCompactionOutcome(
            projectedMessages: projected,
            checkpoint: checkpoint
        )
    }

    private func summarizePreparedSegment(
        _ preparation: AtomSessionCompactionPlanner.Preparation
    ) async throws -> String {
        if preparation.isSplitTurn {
            let historyPrompt = AtomSessionCompactionPlanner.structuredSummarizationPrompt(
                messagesToSummarize: preparation.messagesToSummarize,
                previousSummary: preparation.previousSummary
            )
            let historySummary = try await summarizer.summarize(prompt: historyPrompt)
            let turnPrefixPrompt = AtomSessionCompactionPlanner.splitTurnPrefixPrompt(
                messages: preparation.turnPrefixMessages
            )
            let turnPrefixSummary = try await summarizer.summarize(prompt: turnPrefixPrompt)
            let merged = AtomSessionCompactionPlanner.mergeSplitSummaries(
                historySummary: historySummary,
                turnPrefixSummary: turnPrefixSummary
            )
            return appendFileTags(
                to: merged,
                readFiles: preparation.readFiles,
                modifiedFiles: preparation.modifiedFiles
            )
        }

        let prompt = AtomSessionCompactionPlanner.structuredSummarizationPrompt(
            messagesToSummarize: preparation.messagesToSummarize,
            previousSummary: preparation.previousSummary
        )
        let summaryText = try await summarizer.summarize(prompt: prompt)
        return appendFileTags(
            to: summaryText,
            readFiles: preparation.readFiles,
            modifiedFiles: preparation.modifiedFiles
        )
    }

    private func appendFileTags(
        to summary: String,
        readFiles: [String],
        modifiedFiles: [String]
    ) -> String {
        var body = summary
        if !readFiles.isEmpty {
            body += "\n\n<read-files>\n\(readFiles.joined(separator: "\n"))\n</read-files>"
        }
        if !modifiedFiles.isEmpty {
            body += "\n\n<modified-files>\n\(modifiedFiles.joined(separator: "\n"))\n</modified-files>"
        }
        return body
    }
}
