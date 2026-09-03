import Foundation
import Testing

@testable import OpenCore

private struct SettingsFixedSummarizer: SettingsContextCompactionSummarizing {
    let summary: String

    func summarize(messages: [ChatMessage]) async throws -> String {
        summary
    }

    func summarize(prompt: String) async throws -> String {
        summary
    }
}

@Suite("Settings Context Compaction Engine")
struct SettingsContextCompactionEngineTests {
    @Test("shouldCompact uses Pi reserve headroom rule")
    func shouldCompactUsesReserveHeadroom() {
        let engine = SettingsContextCompactionEngine(
            summarizer: SettingsFixedSummarizer(summary: "summary")
        )
        let messages = [
            ChatMessage.text(role: .user, content: String(repeating: "a", count: 400))
        ]
        let disabled = SettingsContextCompactionPreference(isEnabled: false)
        #expect(engine.shouldCompact(messages: messages, contextLength: 100, preference: disabled) == false)

        let enabled = SettingsContextCompactionPreference(
            isEnabled: true,
            reserveTokens: 20
        )
        #expect(engine.shouldCompact(messages: messages, contextLength: 100, preference: enabled) == true)

        let withinBudget = SettingsContextCompactionPreference(
            isEnabled: true,
            reserveTokens: 90
        )
        #expect(engine.shouldCompact(messages: messages, contextLength: 10_000, preference: withinBudget) == false)
    }

    @Test("compactIfNeeded appends Pi-style checkpoint when session entries exist")
    func compactIfNeededAppendsCheckpoint() async throws {
        let summarizer = SettingsFixedSummarizer(summary: "short summary")
        let engine = SettingsContextCompactionEngine(summarizer: summarizer)
        let atomID = UUID()
        let firstID = UUID()
        let secondID = UUID()
        let thirdID = UUID()

        let entries: [AtomSessionEntry] = [
            .messageEntry(
                id: firstID,
                atomID: atomID,
                parentID: nil,
                message: .text(role: .user, content: String(repeating: "a", count: 400)),
                timestamp: Date(timeIntervalSince1970: 0)
            ),
            .messageEntry(
                id: secondID,
                atomID: atomID,
                parentID: firstID,
                message: .text(role: .assistant, content: String(repeating: "b", count: 400)),
                timestamp: Date(timeIntervalSince1970: 1)
            ),
            .messageEntry(
                id: thirdID,
                atomID: atomID,
                parentID: secondID,
                message: .text(role: .user, content: String(repeating: "c", count: 400)),
                timestamp: Date(timeIntervalSince1970: 2)
            )
        ]

        let messages = entries.compactMap(\.message)
        let preference = SettingsContextCompactionPreference(
            isEnabled: true,
            minRecentMessages: 1,
            reserveTokens: 20,
            keepRecentTokens: 50
        )

        let outcome = try await engine.compactIfNeeded(
            messages: messages,
            sessionEntries: entries,
            leafEntryID: thirdID,
            contextLength: 100,
            preference: preference
        )

        #expect(outcome.checkpoint != nil)
        #expect(outcome.checkpoint?.summary.contains("short summary") == true)
        let hasWrappedSummary = outcome.projectedMessages.contains { message in
            if case let .text(text) = message {
                return text.content.contains("compacted into the following summary")
            }
            return false
        }
        #expect(hasWrappedSummary)
    }

    @Test("compactIfNeeded trims when session entries are empty")
    func compactIfNeededTrimsWithoutEntries() async throws {
        let engine = SettingsContextCompactionEngine(
            summarizer: SettingsFixedSummarizer(summary: "unused")
        )
        let messages = (0..<8).map { index in
            ChatMessage.text(role: index.isMultiple(of: 2) ? .user : .assistant, content: String(repeating: "x", count: 200))
        }
        let preference = SettingsContextCompactionPreference(
            isEnabled: true,
            minRecentMessages: 2,
            reserveTokens: 20
        )

        let outcome = try await engine.compactIfNeeded(
            messages: messages,
            sessionEntries: [],
            leafEntryID: nil,
            contextLength: 100,
            preference: preference
        )

        #expect(outcome.checkpoint == nil)
        #expect(outcome.projectedMessages.count < messages.count)
    }

    @Test("compactManually summarizes without threshold gate")
    func compactManuallySummarizesWithoutThreshold() async throws {
        let summarizer = SettingsFixedSummarizer(summary: "manual summary")
        let engine = SettingsContextCompactionEngine(summarizer: summarizer)
        let atomID = UUID()
        let firstID = UUID()
        let secondID = UUID()
        let thirdID = UUID()

        let entries: [AtomSessionEntry] = [
            .messageEntry(
                id: firstID,
                atomID: atomID,
                parentID: nil,
                message: .text(role: .user, content: "first"),
                timestamp: Date(timeIntervalSince1970: 0)
            ),
            .messageEntry(
                id: secondID,
                atomID: atomID,
                parentID: firstID,
                message: .text(role: .assistant, content: "second"),
                timestamp: Date(timeIntervalSince1970: 1)
            ),
            .messageEntry(
                id: thirdID,
                atomID: atomID,
                parentID: secondID,
                message: .text(role: .user, content: "third"),
                timestamp: Date(timeIntervalSince1970: 2)
            )
        ]

        let messages = entries.compactMap(\.message)
        let preference = SettingsContextCompactionPreference(isEnabled: false)

        let outcome = try await engine.compactManually(
            messages: messages,
            sessionEntries: entries,
            leafEntryID: thirdID,
            contextLength: 0,
            preference: preference
        )

        #expect(outcome.checkpoint != nil)
        #expect(outcome.checkpoint?.summary.contains("manual summary") == true)
    }

    @Test("split-turn compaction merges turn prefix summary")
    func splitTurnCompactionMergesSummaries() async throws {
        let summarizer = SettingsFixedSummarizer(summary: "history-summary")
        let engine = SettingsContextCompactionEngine(summarizer: summarizer)
        let atomID = UUID()
        let userID = UUID()
        let thinkingID = UUID()
        let answerID = UUID()

        let hugeThinking = String(repeating: "reasoning ", count: 3_000)
        let entries: [AtomSessionEntry] = [
            .messageEntry(
                id: userID,
                atomID: atomID,
                parentID: nil,
                message: .text(role: .user, content: "start task"),
                timestamp: Date(timeIntervalSince1970: 0)
            ),
            .messageEntry(
                id: thinkingID,
                atomID: atomID,
                parentID: userID,
                message: .thinking(id: thinkingID, content: hugeThinking, isComplete: true, timestamp: Date(timeIntervalSince1970: 1)),
                timestamp: Date(timeIntervalSince1970: 1)
            ),
            .messageEntry(
                id: answerID,
                atomID: atomID,
                parentID: thinkingID,
                message: .text(role: .assistant, content: "partial answer", isComplete: true, timestamp: Date(timeIntervalSince1970: 2)),
                timestamp: Date(timeIntervalSince1970: 2)
            )
        ]

        let messages = entries.compactMap(\.message)
        let preference = SettingsContextCompactionPreference(isEnabled: false)

        let outcome = try await engine.compactManually(
            messages: messages,
            sessionEntries: entries,
            leafEntryID: answerID,
            contextLength: 0,
            preference: preference
        )

        #expect(outcome.checkpoint?.summary.contains("Current Turn (partial)") == true)
    }
}
