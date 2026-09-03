import Foundation

/// Append-only session tree entry kinds (Pi-style).
nonisolated enum AtomSessionEntryKind: String, Codable, Sendable {
    case message
    case compaction
}

/// Persisted compaction checkpoint appended to the session tree.
nonisolated struct AtomCompactionCheckpoint: Equatable, Codable, Sendable {
    let summary: String
    let firstKeptEntryID: UUID
    let tokensBefore: Int
    let readFiles: [String]
    let modifiedFiles: [String]
}

/// One node in an atom's append-only session tree.
nonisolated struct AtomSessionEntry: Equatable, Identifiable, Sendable {
    let id: UUID
    let atomID: UUID
    let parentID: UUID?
    let kind: AtomSessionEntryKind
    let timestamp: Date
    let message: ChatMessage?
    let compaction: AtomCompactionCheckpoint?

    init(
        id: UUID,
        atomID: UUID,
        parentID: UUID?,
        kind: AtomSessionEntryKind,
        timestamp: Date,
        message: ChatMessage? = nil,
        compaction: AtomCompactionCheckpoint? = nil
    ) {
        self.id = id
        self.atomID = atomID
        self.parentID = parentID
        self.kind = kind
        self.timestamp = timestamp
        self.message = message
        self.compaction = compaction
    }

    static func messageEntry(
        id: UUID,
        atomID: UUID,
        parentID: UUID?,
        message: ChatMessage,
        timestamp: Date
    ) -> AtomSessionEntry {
        AtomSessionEntry(
            id: id,
            atomID: atomID,
            parentID: parentID,
            kind: .message,
            timestamp: timestamp,
            message: message
        )
    }

    static func compactionEntry(
        id: UUID,
        atomID: UUID,
        parentID: UUID?,
        checkpoint: AtomCompactionCheckpoint,
        timestamp: Date
    ) -> AtomSessionEntry {
        AtomSessionEntry(
            id: id,
            atomID: atomID,
            parentID: parentID,
            kind: .compaction,
            timestamp: timestamp,
            compaction: checkpoint
        )
    }
}
