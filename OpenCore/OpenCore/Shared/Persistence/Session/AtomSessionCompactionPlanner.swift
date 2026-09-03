import Foundation

/// Pi-style compaction preparation: token-budget cut points and summarization spans.
nonisolated enum AtomSessionCompactionPlanner {
    struct Preparation: Equatable, Sendable {
        let firstKeptEntryID: UUID
        let messagesToSummarize: [ChatMessage]
        let turnPrefixMessages: [ChatMessage]
        let isSplitTurn: Bool
        let tokensBefore: Int
        let previousSummary: String?
        let readFiles: [String]
        let modifiedFiles: [String]
    }

    struct Settings: Equatable, Sendable {
        var keepRecentTokens: Int = 20_000
    }

    static func prepareCompaction(
        entries: [AtomSessionEntry],
        leafID: UUID?,
        settings: Settings,
        tokensBefore: Int
    ) -> Preparation? {
        let path = AtomSessionContextBuilder.buildPath(entries: entries, leafID: leafID)
        guard !path.isEmpty, path.last?.kind != .compaction else { return nil }

        let previousCompactionIndex = path.lastIndex(where: { $0.kind == .compaction })
        var boundaryStart = 0
        var previousSummary: String?
        if let previousCompactionIndex {
            let previousCompaction = path[previousCompactionIndex]
            previousSummary = previousCompaction.compaction?.summary
            if let firstKept = previousCompaction.compaction?.firstKeptEntryID,
               let keptIndex = path.firstIndex(where: { $0.id == firstKept }) {
                boundaryStart = keptIndex
            } else {
                boundaryStart = previousCompactionIndex + 1
            }
        }

        let messageEntries = path.enumerated().compactMap { index, entry -> (Int, ChatMessage)? in
            guard entry.kind == .message, let message = entry.message else { return nil }
            return (index, message)
        }
        guard messageEntries.count > 1 else { return nil }

        guard let cut = findCutPoint(
            path: path,
            messageEntries: messageEntries,
            boundaryStartIndex: boundaryStart,
            keepRecentTokens: settings.keepRecentTokens
        ) else {
            return nil
        }

        let firstKeptEntryID = path[messageEntries[cut.cutIndex].0].id
        let summarizeEndPathIndex = messageEntries[cut.cutIndex].0
        var messagesToSummarize: [ChatMessage] = []
        for (pathIndex, message) in messageEntries where pathIndex >= boundaryStart && pathIndex < summarizeEndPathIndex {
            messagesToSummarize.append(message)
        }

        let turnPrefixMessages = cut.turnPrefixMessages
        guard !messagesToSummarize.isEmpty || !turnPrefixMessages.isEmpty else { return nil }

        let fileOps = extractFileOperations(from: messagesToSummarize + turnPrefixMessages)

        return Preparation(
            firstKeptEntryID: firstKeptEntryID,
            messagesToSummarize: messagesToSummarize,
            turnPrefixMessages: turnPrefixMessages,
            isSplitTurn: cut.isSplitTurn,
            tokensBefore: tokensBefore,
            previousSummary: previousSummary,
            readFiles: fileOps.readFiles,
            modifiedFiles: fileOps.modifiedFiles
        )
    }

    static func serializeForSummarization(_ messages: [ChatMessage]) -> String {
        messages.map { message in
            switch message {
            case let .text(text):
                let roleLabel = text.role == .assistant ? "Assistant" : "User"
                return "[\(roleLabel)]: \(text.content)"
            case let .thinking(thinking):
                return "[Assistant thinking]: \(thinking.content)"
            case let .system(system):
                return "[System]: \(system.content)"
            case let .outputStream(outputStream):
                let output = String(outputStream.detail.outputTail.prefix(2_000))
                return "[Command]: \(outputStream.command)\n[Output]: \(output)"
            }
        }.joined(separator: "\n")
    }

    static func structuredSummarizationPrompt(
        messagesToSummarize: [ChatMessage],
        previousSummary: String?,
        customInstructions: String? = nil
    ) -> String {
        let conversation = serializeForSummarization(messagesToSummarize)
        var prompt = """
        Summarize the following conversation segment using this structure:

        ## Goal
        ## Constraints & Preferences
        ## Progress
        ### Done
        ### In Progress
        ### Blocked
        ## Key Decisions
        ## Next Steps
        ## Critical Context

        <read-files>
        </read-files>

        <modified-files>
        </modified-files>

        Conversation:
        \(conversation)
        """
        if let previousSummary, !previousSummary.isEmpty {
            prompt += "\n\nPrevious compaction summary to merge and update:\n\(previousSummary)"
        }
        if let customInstructions, !customInstructions.isEmpty {
            prompt += "\n\nAdditional focus:\n\(customInstructions)"
        }
        return prompt
    }

    static func splitTurnPrefixPrompt(messages: [ChatMessage]) -> String {
        let conversation = serializeForSummarization(messages)
        return """
        Summarize the early portion of the current assistant turn. Preserve tool output, decisions, and facts needed to continue the turn.

        Turn prefix:
        \(conversation)
        """
    }

    static func mergeSplitSummaries(historySummary: String, turnPrefixSummary: String) -> String {
        """
        \(historySummary.trimmingCharacters(in: .whitespacesAndNewlines))

        ## Current Turn (partial)
        \(turnPrefixSummary.trimmingCharacters(in: .whitespacesAndNewlines))
        """
    }

    private struct CutPoint {
        let cutIndex: Int
        let isSplitTurn: Bool
        let turnPrefixMessages: [ChatMessage]
    }

    private static func findCutPoint(
        path: [AtomSessionEntry],
        messageEntries: [(Int, ChatMessage)],
        boundaryStartIndex: Int,
        keepRecentTokens: Int
    ) -> CutPoint? {
        guard let lastIndex = messageEntries.indices.last else { return nil }

        let turnStartIndex = messageEntries.lastIndex { pair in
            pair.0 >= boundaryStartIndex && isUserTurnStart(pair.1)
        } ?? boundaryStartIndex

        let turnTokenCount = messageEntries[turnStartIndex...].reduce(0) { partial, pair in
            partial + ContextTokenCounter.countTokens(for: pair.1)
        }

        if turnTokenCount > keepRecentTokens {
            return splitTurnCutPoint(
                messageEntries: messageEntries,
                turnStartIndex: turnStartIndex,
                keepRecentTokens: keepRecentTokens
            )
        }

        var accumulated = 0
        for index in stride(from: lastIndex, through: 0, by: -1) {
            let (pathIndex, message) = messageEntries[index]
            guard pathIndex >= boundaryStartIndex else { break }
            accumulated += ContextTokenCounter.countTokens(for: message)
            if accumulated < keepRecentTokens { continue }

            if let snapped = snapToUserBoundary(
                messageEntries: messageEntries,
                candidateIndex: index,
                boundaryStartIndex: boundaryStartIndex,
                keepRecentTokens: keepRecentTokens
            ) {
                return CutPoint(cutIndex: snapped, isSplitTurn: false, turnPrefixMessages: [])
            }
            return CutPoint(cutIndex: index, isSplitTurn: false, turnPrefixMessages: [])
        }

        return CutPoint(cutIndex: messageEntries.startIndex, isSplitTurn: false, turnPrefixMessages: [])
    }

    private static func splitTurnCutPoint(
        messageEntries: [(Int, ChatMessage)],
        turnStartIndex: Int,
        keepRecentTokens: Int
    ) -> CutPoint? {
        var accumulated = 0
        for index in stride(from: messageEntries.count - 1, through: turnStartIndex, by: -1) {
            let message = messageEntries[index].1
            accumulated += ContextTokenCounter.countTokens(for: message)
            guard accumulated >= keepRecentTokens || index == turnStartIndex else { continue }

            var turnPrefix: [ChatMessage] = []
            if index > turnStartIndex {
                for prefixIndex in turnStartIndex..<index {
                    turnPrefix.append(messageEntries[prefixIndex].1)
                }
            }
            return CutPoint(cutIndex: index, isSplitTurn: !turnPrefix.isEmpty, turnPrefixMessages: turnPrefix)
        }
        return nil
    }

    private static func snapToUserBoundary(
        messageEntries: [(Int, ChatMessage)],
        candidateIndex: Int,
        boundaryStartIndex: Int,
        keepRecentTokens: Int
    ) -> Int? {
        for index in stride(from: candidateIndex, through: 0, by: -1) {
            let (pathIndex, message) = messageEntries[index]
            guard pathIndex >= boundaryStartIndex else { break }
            guard isUserTurnStart(message) else { continue }

            let tailTokens = messageEntries[index...].reduce(0) { partial, pair in
                partial + ContextTokenCounter.countTokens(for: pair.1)
            }
            if tailTokens >= keepRecentTokens {
                return index
            }
        }
        return nil
    }

    private static func isUserTurnStart(_ message: ChatMessage) -> Bool {
        if case let .text(text) = message {
            return text.role == .user
        }
        return false
    }

    private static func extractFileOperations(
        from messages: [ChatMessage]
    ) -> (readFiles: [String], modifiedFiles: [String]) {
        var readFiles = Set<String>()
        var modifiedFiles = Set<String>()
        for message in messages {
            guard case let .outputStream(outputStream) = message else { continue }
            let command = outputStream.command.lowercased()
            if command.contains("read") || command.contains("cat ") {
                readFiles.insert(outputStream.command)
            }
            if command.contains("write") || command.contains("edit") || command.contains("patch") {
                modifiedFiles.insert(outputStream.command)
            }
        }
        return (readFiles.sorted(), modifiedFiles.sorted())
    }
}
