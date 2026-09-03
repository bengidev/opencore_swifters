import Foundation
import SwiftData
import Testing

@testable import OpenCore

@Suite("Persistence Atom History")
struct PersistenceAtomHistoryStoringTests {
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

    @Test("Output stream detailJSON round trips through SwiftData")
    @MainActor
    func outputStreamDetailRoundTrip() async throws {
        let schema = Schema([AtomEntity.self, AtomMessageEntity.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let store = PersistenceAtomHistoryStore.live(modelContainer: container)

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
    @MainActor
    func listEntriesIncludeLastMessagePreview() async throws {
        let schema = Schema([AtomEntity.self, AtomMessageEntity.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let store = PersistenceAtomHistoryStore.live(modelContainer: container)

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

    @Test("Corrupt detailJSON derives status from isComplete")
    @MainActor
    func corruptDetailJSONFallback() async throws {
        let schema = Schema([AtomEntity.self, AtomMessageEntity.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let atomEntity = AtomEntity(
            id: UUID(),
            title: "Test",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        context.insert(atomEntity)

        let completeEntity = AtomMessageEntity(
            id: UUID(),
            kindRaw: ChatMessageKind.outputStream.rawValue,
            role: ChatMessageRole.system.rawValue,
            content: "npm test",
            isComplete: true,
            timestamp: Date(timeIntervalSince1970: 1),
            order: 0,
            detailJSON: "not-valid-json",
            atom: atomEntity
        )
        atomEntity.messages.append(completeEntity)
        context.insert(completeEntity)

        let incompleteEntity = AtomMessageEntity(
            id: UUID(),
            kindRaw: ChatMessageKind.outputStream.rawValue,
            role: ChatMessageRole.system.rawValue,
            content: "git status",
            isComplete: false,
            timestamp: Date(timeIntervalSince1970: 2),
            order: 1,
            detailJSON: "{bad",
            atom: atomEntity
        )
        atomEntity.messages.append(incompleteEntity)
        context.insert(incompleteEntity)
        try context.save()

        let store = PersistenceAtomHistoryStore.live(modelContainer: container)
        let loaded = try await store.loadChatMessages(atomID: atomEntity.id)
        #expect(loaded.count == 2)

        guard case let .outputStream(completeOutput) = loaded[0],
              case let .outputStream(incompleteOutput) = loaded[1] else {
            Issue.record("Expected outputStream messages")
            return
        }
        #expect(completeOutput.detail.status == .completed)
        #expect(incompleteOutput.detail.status == .running)
    }
}
