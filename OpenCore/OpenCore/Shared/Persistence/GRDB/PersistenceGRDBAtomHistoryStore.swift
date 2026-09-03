import Foundation
import GRDB
import SwiftData

extension PersistenceAtomHistoryStore {
  @MainActor
    static func live(database: PersistenceGRDBDatabase) -> Self {
        let repository = PersistenceGRDBAtomHistoryRepository(database: database)
        return Self(
            listAtomEntries: { try await MainActor.run { try repository.listAtomEntries() } },
            listAtoms: { try await MainActor.run { try repository.listAtoms() } },
            loadChatMessages: { atomID in
                try await MainActor.run { try repository.loadDisplayMessages(atomID: atomID) }
            },
            loadProjectedChatMessages: { atomID in
                try await MainActor.run { try repository.loadProjectedMessages(atomID: atomID) }
            },
            loadSessionEntries: { atomID in
                try await MainActor.run { try repository.loadSessionEntries(atomID: atomID) }
            },
            loadLeafEntryID: { atomID in
                try await MainActor.run { try repository.leafEntryID(atomID: atomID) }
            },
            saveAtom: { atom in try await MainActor.run { try repository.saveAtom(atom) } },
            appendChatMessage: { atomID, message in
                try await MainActor.run { try repository.appendChatMessage(atomID: atomID, message: message) }
            },
            replaceChatMessages: { atomID, messages in
                try await MainActor.run { try repository.syncMessageEntries(atomID: atomID, messages: messages) }
            },
            appendCompaction: { atomID, checkpoint in
                try await MainActor.run { try repository.appendCompaction(atomID: atomID, checkpoint: checkpoint) }
            },
            deleteAtom: { atomID in try await MainActor.run { try repository.deleteAtom(atomID: atomID) } },
            setPinned: { atomID, isPinned in
                try await MainActor.run { try repository.setPinned(atomID: atomID, isPinned: isPinned) }
            },
            renameAtom: { atomID, title in
                try await MainActor.run { try repository.renameAtom(atomID: atomID, title: title) }
            },
            setGroup: { atomID, groupName in
                try await MainActor.run { try repository.setGroup(atomID: atomID, groupName: groupName) }
            },
            listGroups: { try await MainActor.run { try repository.listGroups() } }
        )
    }

    @MainActor
    static func sweepExpiredVoiceAttachments(
        database: PersistenceGRDBDatabase,
        now: Date = .now
    ) throws {
        let repository = PersistenceGRDBAtomHistoryRepository(database: database)
        try repository.sweepExpiredVoiceAttachments(now: now)
    }

    @MainActor
    static func migrateSwiftDataIfNeeded(
        database: PersistenceGRDBDatabase,
        modelContainer: ModelContainer
    ) throws {
        let migrationKey = "swiftdata_atoms_migrated_v1"
        if try database.metadataValue(for: migrationKey) == "1" {
            return
        }

        let repository = PersistenceGRDBAtomHistoryRepository(database: database)
        let existing = try repository.listAtoms()
        guard existing.isEmpty else {
            try database.setMetadataValue("1", for: migrationKey)
            return
        }

        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<AtomEntity>()
        let entities = try context.fetch(descriptor)
        guard !entities.isEmpty else {
            try database.setMetadataValue("1", for: migrationKey)
            return
        }

        for entity in entities {
            let atom = Atom(
                id: entity.id,
                title: entity.title,
                createdAt: entity.createdAt,
                updatedAt: entity.updatedAt,
                isPinned: entity.isPinned,
                groupName: entity.groupName
            )
            try repository.importAtom(atom)
            let messages = entity.messages
                .sorted { $0.order < $1.order }
                .compactMap(PersistenceSwiftDataAtomMigrationSupport.chatMessage(from:))
            for message in messages {
                try repository.appendChatMessage(atomID: atom.id, message: message)
            }
        }

        try database.setMetadataValue("1", for: migrationKey)
    }
}

/// GRDB implementation of append-only Pi-style atom session storage.
@MainActor
final class PersistenceGRDBAtomHistoryRepository {
    private let database: PersistenceGRDBDatabase

    init(database: PersistenceGRDBDatabase) {
        self.database = database
    }

    func listAtoms() throws -> [Atom] {
        try database.pool.read { db in
            try AtomRecord.fetchAll(db).map(atom(from:))
        }
    }

    func listAtomEntries() throws -> [AtomListEntry] {
        let atoms = try listAtoms()
        return try atoms.map { atom in
            let entries = try loadSessionEntries(atomID: atom.id)
            if let last = AtomSessionContextBuilder.lastListableMessage(in: entries) {
                return AtomListEntry(
                    atom: atom,
                    lastMessagePreview: last.preview,
                    lastMessageAt: last.timestamp
                )
            }
            let fallback = atom.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return AtomListEntry(
                atom: atom,
                lastMessagePreview: fallback.isEmpty ? "New atom" : fallback,
                lastMessageAt: atom.updatedAt
            )
        }
        .sorted { lhs, rhs in
            if lhs.atom.isPinned != rhs.atom.isPinned { return lhs.atom.isPinned }
            return lhs.lastMessageAt > rhs.lastMessageAt
        }
    }

    func loadDisplayMessages(atomID: UUID) throws -> [ChatMessage] {
        let entries = try loadSessionEntries(atomID: atomID)
        return AtomSessionContextBuilder.buildDisplayMessages(entries: entries)
    }

    func loadProjectedMessages(atomID: UUID) throws -> [ChatMessage] {
        let entries = try loadSessionEntries(atomID: atomID)
        let leafID = try leafEntryID(atomID: atomID)
        return AtomSessionContextBuilder.buildModelMessages(entries: entries, leafID: leafID)
    }

    func loadSessionEntries(atomID: UUID) throws -> [AtomSessionEntry] {
        try database.pool.read { db in
            let records = try SessionEntryRecord
                .filter(SessionEntryRecord.Columns.atomID == atomID.uuidString)
                .order(SessionEntryRecord.Columns.sortIndex.asc)
                .fetchAll(db)
            return try records.map(entry(from:))
        }
    }

    func saveAtom(_ atom: Atom) throws {
        try database.pool.write { db in
            let record = atomRecord(from: atom)
            try record.save(db)
        }
    }

    func importAtom(_ atom: Atom) throws {
        try saveAtom(atom)
    }

    func appendChatMessage(atomID: UUID, message: ChatMessage) throws {
        try database.pool.write { db in
            let atomIDString = atomID.uuidString
            guard try AtomRecord.fetchOne(db, key: atomIDString) != nil else {
                throw PersistenceAtomHistoryError.atomNotFound(atomID)
            }

            if try SessionEntryRecord.fetchOne(db, key: message.id.uuidString) != nil {
                try updateMessageRecord(db: db, message: message)
                return
            }

            let parentID = try AtomRecord.fetchOne(db, key: atomIDString)?.leafEntryID
            let sortIndex = try nextSortIndex(db: db, atomID: atomIDString)
            let payload = try AtomSessionMessageCodec.encode(message)
            let record = SessionEntryRecord(
                id: message.id.uuidString,
                atomID: atomIDString,
                parentID: parentID,
                kind: AtomSessionEntryKind.message.rawValue,
                payload: payload,
                timestamp: message.timestamp.timeIntervalSince1970,
                sortIndex: sortIndex
            )
            try record.insert(db)
            try db.execute(
                sql: "UPDATE atoms SET leaf_entry_id = ?, updated_at = ? WHERE id = ?",
                arguments: [record.id, message.timestamp.timeIntervalSince1970, atomIDString]
            )
        }
    }

    func appendCompaction(atomID: UUID, checkpoint: AtomCompactionCheckpoint) throws {
        try database.pool.write { db in
            let atomIDString = atomID.uuidString
            guard try AtomRecord.fetchOne(db, key: atomIDString) != nil else {
                throw PersistenceAtomHistoryError.atomNotFound(atomID)
            }

            let entryID = UUID()
            let parentID = try AtomRecord.fetchOne(db, key: atomIDString)?.leafEntryID
            let sortIndex = try nextSortIndex(db: db, atomID: atomIDString)
            let payload = try AtomSessionMessageCodec.encodeCompaction(checkpoint)
            let timestamp = Date().timeIntervalSince1970
            let record = SessionEntryRecord(
                id: entryID.uuidString,
                atomID: atomIDString,
                parentID: parentID,
                kind: AtomSessionEntryKind.compaction.rawValue,
                payload: payload,
                timestamp: timestamp,
                sortIndex: sortIndex
            )
            try record.insert(db)
            try db.execute(
                sql: "UPDATE atoms SET leaf_entry_id = ?, updated_at = ? WHERE id = ?",
                arguments: [record.id, timestamp, atomIDString]
            )
        }
    }

    /// Appends message entries that are not already stored. Never deletes history.
    func syncMessageEntries(atomID: UUID, messages: [ChatMessage]) throws {
        for message in messages where !isSyntheticCompactionSummary(message) {
            if try messageEntryExists(atomID: atomID, messageID: message.id) {
                try updateMessageIfExists(message)
            } else {
                try appendChatMessage(atomID: atomID, message: message)
            }
        }
    }

    func deleteAtom(atomID: UUID) throws {
        let messages = try loadDisplayMessages(atomID: atomID)
        ChatAttachmentStore.removeAll(at: ChatAttachmentStore.localPaths(in: messages))
        try database.pool.write { db in
            _ = try AtomRecord.deleteOne(db, key: atomID.uuidString)
        }
    }

    func setPinned(atomID: UUID, isPinned: Bool) throws {
        try database.pool.write { db in
            guard var record = try AtomRecord.fetchOne(db, key: atomID.uuidString) else { return }
            record.isPinned = isPinned
            try record.update(db)
        }
    }

    func renameAtom(atomID: UUID, title: String) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try database.pool.write { db in
            guard var record = try AtomRecord.fetchOne(db, key: atomID.uuidString) else { return }
            record.title = trimmed
            record.updatedAt = Date().timeIntervalSince1970
            try record.update(db)
        }
    }

    func setGroup(atomID: UUID, groupName: String?) throws {
        try database.pool.write { db in
            guard var record = try AtomRecord.fetchOne(db, key: atomID.uuidString) else { return }
            if let groupName {
                let trimmed = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                record.groupName = trimmed
            } else {
                record.groupName = nil
            }
            try record.update(db)
        }
    }

    func listGroups() throws -> [String] {
        try database.pool.read { db in
            let records = try AtomRecord.fetchAll(db)
            let groups = Set(records.compactMap(\.groupName))
            return groups.sorted()
        }
    }

    func sweepExpiredVoiceAttachments(now: Date) throws {
        let cutoff = ChatVoiceAttachmentRetention.expirationCutoff(from: now)
        let atoms = try listAtoms()
        for atom in atoms {
            let entries = try loadSessionEntries(atomID: atom.id)
            let messages = AtomSessionContextBuilder.buildDisplayMessages(entries: entries)
            let result = ChatVoiceAttachmentRetention.expireVoiceAttachments(
                in: messages,
                cutoff: cutoff
            )
            guard !result.removedPaths.isEmpty else { continue }
            ChatAttachmentStore.removeAll(at: result.removedPaths)
            for message in result.messages where !isSyntheticCompactionSummary(message) {
                try updateMessageIfExists(message)
            }
        }
    }

    func leafEntryID(atomID: UUID) throws -> UUID? {
        try database.pool.read { db in
            guard let leaf = try AtomRecord.fetchOne(db, key: atomID.uuidString)?.leafEntryID else {
                return nil
            }
            return UUID(uuidString: leaf)
        }
    }

    private func messageEntryExists(atomID: UUID, messageID: UUID) throws -> Bool {
        try database.pool.read { db in
            try SessionEntryRecord.fetchOne(db, key: messageID.uuidString) != nil
        }
    }

    private func updateMessageIfExists(_ message: ChatMessage) throws {
        try database.pool.write { db in
            try updateMessageRecord(db: db, message: message)
        }
    }

    private func updateMessageRecord(db: Database, message: ChatMessage) throws {
        guard var record = try SessionEntryRecord.fetchOne(db, key: message.id.uuidString) else { return }
        record.payload = try AtomSessionMessageCodec.encode(message)
        record.timestamp = message.timestamp.timeIntervalSince1970
        try record.update(db)
    }

    private func nextSortIndex(db: Database, atomID: String) throws -> Int {
        let maxIndex = try Int.fetchOne(
            db,
            sql: "SELECT COALESCE(MAX(sort_index), -1) FROM session_entries WHERE atom_id = ?",
            arguments: [atomID]
        ) ?? -1
        return maxIndex + 1
    }

    private func isSyntheticCompactionSummary(_ message: ChatMessage) -> Bool {
        guard case let .text(text) = message else { return false }
        return text.content.hasPrefix(AtomSessionContextBuilder.compactionSummaryPrefix)
    }

    private func atom(from record: AtomRecord) -> Atom {
        Atom(
            id: UUID(uuidString: record.id) ?? UUID(),
            title: record.title,
            createdAt: Date(timeIntervalSince1970: record.createdAt),
            updatedAt: Date(timeIntervalSince1970: record.updatedAt),
            isPinned: record.isPinned,
            groupName: record.groupName
        )
    }

    private func atomRecord(from atom: Atom) -> AtomRecord {
        AtomRecord(
            id: atom.id.uuidString,
            title: atom.title,
            createdAt: atom.createdAt.timeIntervalSince1970,
            updatedAt: atom.updatedAt.timeIntervalSince1970,
            isPinned: atom.isPinned,
            groupName: atom.groupName,
            leafEntryID: nil
        )
    }

    private func entry(from record: SessionEntryRecord) throws -> AtomSessionEntry {
        let atomID = UUID(uuidString: record.atomID) ?? UUID()
        let entryID = UUID(uuidString: record.id) ?? UUID()
        let parentID = record.parentID.flatMap(UUID.init(uuidString:))
        let kind = AtomSessionEntryKind(rawValue: record.kind) ?? .message
        let timestamp = Date(timeIntervalSince1970: record.timestamp)

        switch kind {
        case .message:
            let message = try AtomSessionMessageCodec.decode(data: record.payload, messageID: entryID)
            return .messageEntry(
                id: entryID,
                atomID: atomID,
                parentID: parentID,
                message: message,
                timestamp: timestamp
            )
        case .compaction:
            let checkpoint = try AtomSessionMessageCodec.decodeCompaction(data: record.payload)
            return .compactionEntry(
                id: entryID,
                atomID: atomID,
                parentID: parentID,
                checkpoint: checkpoint,
                timestamp: timestamp
            )
        }
    }
}
