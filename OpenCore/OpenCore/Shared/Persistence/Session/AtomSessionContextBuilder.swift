import Foundation

/// Pi-style compaction-aware projection from append-only session entries to model context.
nonisolated enum AtomSessionContextBuilder {
    static let compactionSummaryPrefix = """
    The conversation history before this point was compacted into the following summary:

    <summary>
    """

    static let compactionSummarySuffix = """
    </summary>
    """

    /// Walks from leaf to root, then applies the latest compaction boundary.
    static func buildPath(
        entries: [AtomSessionEntry],
        leafID: UUID?
    ) -> [AtomSessionEntry] {
        guard !entries.isEmpty else { return [] }
        let byID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        let resolvedLeafID = leafID ?? entries.last?.id
        guard let resolvedLeafID, var current = byID[resolvedLeafID] else { return [] }

        var path: [AtomSessionEntry] = []
        while true {
            path.append(current)
            guard let parentID = current.parentID, let parent = byID[parentID] else { break }
            current = parent
        }
        return path.reversed()
    }

    /// Returns active entries honoring the latest compaction checkpoint on the path.
    static func buildContextEntries(
        entries: [AtomSessionEntry],
        leafID: UUID?
    ) -> [AtomSessionEntry] {
        let path = buildPath(entries: entries, leafID: leafID)
        guard let compactionIndex = path.lastIndex(where: { $0.kind == .compaction }) else {
            return path
        }

        let compaction = path[compactionIndex]
        guard let firstKeptEntryID = compaction.compaction?.firstKeptEntryID else {
            return path
        }

        var contextEntries: [AtomSessionEntry] = [compaction]
        var foundFirstKept = false
        for index in 0..<compactionIndex {
            let entry = path[index]
            if entry.id == firstKeptEntryID {
                foundFirstKept = true
            }
            if foundFirstKept {
                contextEntries.append(entry)
            }
        }
        contextEntries.append(contentsOf: path[(compactionIndex + 1)...])
        return contextEntries
    }

    /// All persisted message entries in chronological order for UI restore.
    static func buildDisplayMessages(entries: [AtomSessionEntry]) -> [ChatMessage] {
        entries.compactMap { entry in
            guard entry.kind == .message else { return nil }
            return entry.message
        }
    }

    /// Projects session entries into the compaction-aware context the model should see.
    static func buildModelMessages(
        entries: [AtomSessionEntry],
        leafID: UUID?
    ) -> [ChatMessage] {
        buildContextEntries(entries: entries, leafID: leafID).flatMap(entryToModelMessages)
    }

    static func entryToModelMessages(_ entry: AtomSessionEntry) -> [ChatMessage] {
        switch entry.kind {
        case .message:
            guard let message = entry.message else { return [] }
            return [message]
        case .compaction:
            guard let compaction = entry.compaction else { return [] }
            let wrapped = compactionSummaryPrefix + compaction.summary + compactionSummarySuffix
            return [
                .text(
                    id: entry.id,
                    role: .user,
                    content: wrapped,
                    timestamp: entry.timestamp
                )
            ]
        }
    }

    static func listPreview(for message: ChatMessage) -> String? {
        switch message {
        case let .text(text):
            let content = text.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if content.hasPrefix(compactionSummaryPrefix.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return "Compacted summary"
            }
            if !content.isEmpty { return content }
            if !text.attachments.isEmpty { return "Attachment" }
            return nil
        case let .system(system):
            let content = system.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return content.isEmpty ? nil : content
        case let .outputStream(outputStream):
            let command = outputStream.command.trimmingCharacters(in: .whitespacesAndNewlines)
            return command.isEmpty ? nil : command
        case .thinking:
            return nil
        }
    }

    static func lastListableMessage(in entries: [AtomSessionEntry]) -> (preview: String, timestamp: Date)? {
        for entry in entries.reversed() where entry.kind == .message {
            guard let message = entry.message,
                  let preview = listPreview(for: message) else {
                continue
            }
            return (preview, entry.timestamp)
        }
        return nil
    }
}
