import Foundation
import GRDB

enum PersistenceGRDBError: Error, Equatable {
    case databaseUnavailable
    case encodingFailed
    case decodingFailed
}

/// GRDB-backed database pool for atom session storage.
final class PersistenceGRDBDatabase: Sendable {
    let pool: DatabasePool

    init(pool: DatabasePool) {
        self.pool = pool
    }

    static func make() throws -> PersistenceGRDBDatabase {
        let fileManager = FileManager.default
        let supportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = supportURL.appendingPathComponent("OpenCore", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let databaseURL = directory.appendingPathComponent("atoms.sqlite")

        var configuration = Configuration()
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }

        let pool = try DatabasePool(path: databaseURL.path, configuration: configuration)
        let database = PersistenceGRDBDatabase(pool: pool)
        try database.migrate()
        return database
    }

    static func inMemory() throws -> PersistenceGRDBDatabase {
        let pool = try DatabasePool(path: ":memory:")
        let database = PersistenceGRDBDatabase(pool: pool)
        try database.migrate()
        return database
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_atoms_and_session_entries") { db in
            try db.create(table: "atoms") { table in
                table.column("id", .text).primaryKey()
                table.column("title", .text).notNull()
                table.column("created_at", .double).notNull()
                table.column("updated_at", .double).notNull()
                table.column("is_pinned", .boolean).notNull().defaults(to: false)
                table.column("group_name", .text)
                table.column("leaf_entry_id", .text)
            }

            try db.create(table: "session_entries") { table in
                table.column("id", .text).primaryKey()
                table.column("atom_id", .text)
                    .notNull()
                    .references("atoms", onDelete: .cascade)
                table.column("parent_id", .text)
                table.column("kind", .text).notNull()
                table.column("payload", .blob).notNull()
                table.column("timestamp", .double).notNull()
                table.column("sort_index", .integer).notNull()
            }

            try db.create(index: "session_entries_atom_id", on: "session_entries", columns: ["atom_id"])
            try db.create(index: "session_entries_parent_id", on: "session_entries", columns: ["parent_id"])

            try db.create(table: "app_metadata") { table in
                table.column("key", .text).primaryKey()
                table.column("value", .text).notNull()
            }
        }

        try migrator.migrate(pool)
    }

    func metadataValue(for key: String) throws -> String? {
        try pool.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM app_metadata WHERE key = ?", arguments: [key])
        }
    }

    func setMetadataValue(_ value: String, for key: String) throws {
        try pool.write { db in
            try db.execute(
                sql: """
                INSERT INTO app_metadata (key, value) VALUES (?, ?)
                ON CONFLICT(key) DO UPDATE SET value = excluded.value
                """,
                arguments: [key, value]
            )
        }
    }
}

struct AtomRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "atoms"

    var id: String
    var title: String
    var createdAt: Double
    var updatedAt: Double
    var isPinned: Bool
    var groupName: String?
    var leafEntryID: String?

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let title = Column(CodingKeys.title)
        static let createdAt = Column(CodingKeys.createdAt)
        static let updatedAt = Column(CodingKeys.updatedAt)
        static let isPinned = Column(CodingKeys.isPinned)
        static let groupName = Column(CodingKeys.groupName)
        static let leafEntryID = Column(CodingKeys.leafEntryID)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isPinned = "is_pinned"
        case groupName = "group_name"
        case leafEntryID = "leaf_entry_id"
    }
}

struct SessionEntryRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "session_entries"

    var id: String
    var atomID: String
    var parentID: String?
    var kind: String
    var payload: Data
    var timestamp: Double
    var sortIndex: Int

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let atomID = Column(CodingKeys.atomID)
        static let parentID = Column(CodingKeys.parentID)
        static let kind = Column(CodingKeys.kind)
        static let payload = Column(CodingKeys.payload)
        static let timestamp = Column(CodingKeys.timestamp)
        static let sortIndex = Column(CodingKeys.sortIndex)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case atomID = "atom_id"
        case parentID = "parent_id"
        case kind
        case payload
        case timestamp
        case sortIndex = "sort_index"
    }
}
