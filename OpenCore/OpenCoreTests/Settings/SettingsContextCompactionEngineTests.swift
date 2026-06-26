import Foundation
import Testing

@testable import OpenCore

private struct SettingsFixedSummarizer: SettingsContextCompactionSummarizing {
    let summary: String

    func summarize(messages: [ChatMessage]) async throws -> String {
        summary
    }
}

@Suite("Settings Context Compaction Engine")
struct SettingsContextCompactionEngineTests {
    @Test("shouldCompact gates on threshold and enabled flag")
    func shouldCompactGates() {
        let engine = SettingsContextCompactionEngine()
        let messages = [
            ChatMessage.text(role: .user, content: String(repeating: "a", count: 400))
        ]
        let preference = SettingsContextCompactionPreference(isEnabled: false, triggerThresholdPercent: 10)

        #expect(engine.shouldCompact(messages: messages, contextLength: 100, preference: preference) == false)

        let enabled = SettingsContextCompactionPreference(isEnabled: true, triggerThresholdPercent: 10, minRecentMessages: 0)
        #expect(engine.shouldCompact(messages: messages, contextLength: 100, preference: enabled) == true)
    }

    @Test("compactIfNeeded summarizes when trim cannot reach threshold")
    func summarizesWhenTrimInsufficient() async throws {
        let summarizer = SettingsFixedSummarizer(summary: "short summary")
        let engine = SettingsContextCompactionEngine(summarizer: summarizer)
        let messages = (0..<8).map { index in
            ChatMessage.text(role: index.isMultiple(of: 2) ? .user : .assistant, content: String(repeating: "x", count: 200))
        }
        let preference = SettingsContextCompactionPreference(isEnabled: true, triggerThresholdPercent: 50, minRecentMessages: 2)

        let compacted = try await engine.compactIfNeeded(
            messages: messages,
            contextLength: 100,
            preference: preference
        )

        #expect(compacted.count < messages.count)
        let hasSummary = compacted.contains { message in
            if case let .system(system) = message {
                return system.content.contains("short summary")
            }
            return false
        }
        #expect(hasSummary)
    }
}
