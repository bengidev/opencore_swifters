import Foundation
import Testing

@testable import OpenCore

@Suite("Persistence Atom History")
@MainActor
struct PersistenceAtomHistoryStoringTests {
    private func makeStore() throws -> PersistenceAtomHistoryStore {
        let database = try PersistenceGRDBDatabase.inMemory()
        return PersistenceAtomHistoryStore.live(database: database)
    }

    @Test("Preview store returns empty atoms")
    func previewReturnsEmpty() async throws {
        let store = PersistenceAtomHistoryStore.preview
        let atoms = try await store.listAtoms()
        #expect(atoms.isEmpty)
    }

    @Test("Preview store returns empty messages")
    func previewReturnsEmptyMessages() async throws {
        let store = PersistenceAtomHistoryStore.preview
        let messages = try await store.loadChatMessages(atomID: UUID())
        #expect(messages.isEmpty)
    }

    @Test("Output stream detailJSON round trips through GRDB")
    func outputStreamDetailRoundTrip() async throws {
        let store = try makeStore()

        let atomID = UUID()
        let atom = Atom(
            id: atomID,
            title: "Test",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        try await store.saveAtom(atom)

        let messageID = UUID()
        var detail = ChatOutputStreamDetail(status: .completed, cwd: "/tmp")
        detail.appendOutput("line1\nline2\n")
        detail.exitCode = 0
        detail.durationMs = 500
        let message: ChatMessage = .outputStream(
            id: messageID,
            command: "npm test",
            detail: detail,
            isComplete: true,
            timestamp: Date(timeIntervalSince1970: 1)
        )
        try await store.appendChatMessage(atomID: atomID, message: message)

        let loaded = try await store.loadChatMessages(atomID: atomID)
        #expect(loaded.count == 1)
        guard case let .outputStream(loadedOutput) = loaded[0] else {
            Issue.record("Expected outputStream message")
            return
        }
        #expect(loadedOutput.id == messageID)
        #expect(loadedOutput.command == "npm test")
        #expect(loadedOutput.detail.status == .completed)
        #expect(loadedOutput.detail.outputTail == "line1\nline2\n")
        #expect(loadedOutput.detail.cwd == "/tmp")
        #expect(loadedOutput.detail.exitCode == 0)
        #expect(loadedOutput.detail.durationMs == 500)
        #expect(loadedOutput.isComplete == true)
    }

    @Test("List entries include last message preview")
    func listEntriesIncludeLastMessagePreview() async throws {
        let store = try makeStore()

        let atomID = UUID()
        try await store.saveAtom(Atom(
            id: atomID,
            title: "Title",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        ))
        try await store.appendChatMessage(
            atomID: atomID,
            message: .text(role: .user, content: "Latest preview", timestamp: Date(timeIntervalSince1970: 5))
        )

        let entries = try await store.listAtomEntries()
        #expect(entries.count == 1)
        #expect(entries[0].lastMessagePreview == "Latest preview")
    }

    @Test("Compaction checkpoint preserves full history and projects summary")
    func compactionCheckpointPreservesHistory() async throws {
        let store = try makeStore()
        let atomID = UUID()
        try await store.saveAtom(Atom(
            id: atomID,
            title: "Compaction",
            createdAt: .now,
            updatedAt: .now
        ))

        let firstID = UUID()
        let secondID = UUID()
        try await store.appendChatMessage(
            atomID: atomID,
            message: .text(id: firstID, role: .user, content: "old", timestamp: Date(timeIntervalSince1970: 0))
        )
        try await store.appendChatMessage(
            atomID: atomID,
            message: .text(id: secondID, role: .user, content: "recent", timestamp: Date(timeIntervalSince1970: 1))
        )

        let checkpoint = AtomCompactionCheckpoint(
            summary: "merged history",
            firstKeptEntryID: secondID,
            tokensBefore: 1_000,
            readFiles: [],
            modifiedFiles: []
        )
        try await store.appendCompaction(atomID: atomID, checkpoint: checkpoint)

        let rawEntries = try await store.loadSessionEntries(atomID: atomID)
        #expect(rawEntries.count == 3)
        #expect(rawEntries.filter { $0.kind == .message }.count == 2)
        #expect(rawEntries.filter { $0.kind == .compaction }.count == 1)

        let projected = try await store.loadProjectedChatMessages(atomID: atomID)
        #expect(projected.count == 2)
        #expect(projected[0].role == .user)
        #expect(projected[0].id != firstID)
        guard case let .text(recent) = projected[1] else {
            Issue.record("Expected recent text message")
            return
        }
        #expect(recent.content == "recent")

        let display = try await store.loadChatMessages(atomID: atomID)
        #expect(display.count == 2)
        guard case let .text(old) = display[0] else {
            Issue.record("Expected old text message")
            return
        }
        #expect(old.content == "old")
    }
}
