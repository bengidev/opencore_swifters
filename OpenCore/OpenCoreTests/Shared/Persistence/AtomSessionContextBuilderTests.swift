import Foundation
import Testing

@testable import OpenCore

@Suite("Atom Session Context Builder")
struct AtomSessionContextBuilderTests {
    @Test("buildDisplayMessages returns every persisted message entry")
    func buildDisplayMessagesReturnsAllMessages() {
        let atomID = UUID()
        let firstID = UUID()
        let secondID = UUID()
        let compactionID = UUID()

        let entries: [AtomSessionEntry] = [
            .messageEntry(
                id: firstID,
                atomID: atomID,
                parentID: nil,
                message: .text(role: .user, content: "old"),
                timestamp: .now
            ),
            .messageEntry(
                id: secondID,
                atomID: atomID,
                parentID: firstID,
                message: .text(role: .assistant, content: "kept"),
                timestamp: .now
            ),
            .compactionEntry(
                id: compactionID,
                atomID: atomID,
                parentID: secondID,
                checkpoint: AtomCompactionCheckpoint(
                    summary: "summary",
                    firstKeptEntryID: secondID,
                    tokensBefore: 100,
                    readFiles: [],
                    modifiedFiles: []
                ),
                timestamp: .now
            )
        ]

        let display = AtomSessionContextBuilder.buildDisplayMessages(entries: entries)
        #expect(display.count == 2)
        guard case let .text(old) = display[0] else {
            Issue.record("Expected old message")
            return
        }
        #expect(old.content == "old")
    }

    @Test("buildContextEntries omits summarized span after compaction")
    func buildContextEntriesOmitsSummarizedSpan() {
        let atomID = UUID()
        let firstID = UUID()
        let secondID = UUID()
        let compactionID = UUID()

        let entries: [AtomSessionEntry] = [
            .messageEntry(
                id: firstID,
                atomID: atomID,
                parentID: nil,
                message: .text(role: .user, content: "old"),
                timestamp: .now
            ),
            .messageEntry(
                id: secondID,
                atomID: atomID,
                parentID: firstID,
                message: .text(role: .assistant, content: "kept"),
                timestamp: .now
            ),
            .compactionEntry(
                id: compactionID,
                atomID: atomID,
                parentID: secondID,
                checkpoint: AtomCompactionCheckpoint(
                    summary: "summary",
                    firstKeptEntryID: secondID,
                    tokensBefore: 100,
                    readFiles: [],
                    modifiedFiles: []
                ),
                timestamp: .now
            )
        ]

        let contextEntries = AtomSessionContextBuilder.buildContextEntries(
            entries: entries,
            leafID: compactionID
        )
        #expect(contextEntries.count == 2)
        #expect(contextEntries[0].kind == .compaction)
        #expect(contextEntries[1].id == secondID)

        let projected = AtomSessionContextBuilder.buildModelMessages(
            entries: entries,
            leafID: compactionID
        )
        #expect(projected.count == 2)
        guard case let .text(summary) = projected[0] else {
            Issue.record("Expected wrapped summary")
            return
        }
        #expect(summary.content.contains("summary"))
    }
}
