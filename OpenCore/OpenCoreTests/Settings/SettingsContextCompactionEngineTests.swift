import Foundation
import Testing

@testable import OpenCore

private struct SettingsFixedSummarizer: SettingsContextCompactionSummarizing {
    let summary: String

    func summarize(messages: [ChatMessage]) async throws -> String {
        summary
    }
}

private struct DropFirstTrimStrategy: SettingsContextCompactionStrategizing {
    func compact(
        messages: [ChatMessage],
        contextLength: Int,
        thresholdPercent: Int,
        minRecentMessages: Int
    ) async throws -> [ChatMessage] {
        guard messages.count > minRecentMessages + 1 else { return messages }
        return Array(messages.dropFirst())
    }
}

private struct RecordingCompactInputStrategy: SettingsContextCompactionStrategizing {
    let recorder: SettingsCompactionSummarizeRecorder
    private let inner: SettingsContextCompactionSummarizeStrategy

    init(recorder: SettingsCompactionSummarizeRecorder) {
        self.recorder = recorder
        self.inner = SettingsContextCompactionSummarizeStrategy(summarizer: recorder)
    }

    func compact(
        messages: [ChatMessage],
        contextLength: Int,
        thresholdPercent: Int,
        minRecentMessages: Int
    ) async throws -> [ChatMessage] {
        recorder.recordCompactInput(messages)
        return try await inner.compact(
            messages: messages,
            contextLength: contextLength,
            thresholdPercent: thresholdPercent,
            minRecentMessages: minRecentMessages
        )
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
        let preference = SettingsContextCompactionPreference(
            isEnabled: true,
            triggerThresholdPercent: 50,
            minRecentMessages: 2
        )

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

    @Test("summarize receives trim output, not the original message list")
    func summarizeUsesTrimmedMessages() async throws {
        let recorder = SettingsCompactionSummarizeRecorder()
        let engine = SettingsContextCompactionEngine(
            trimStrategy: DropFirstTrimStrategy(),
            summarizeStrategy: RecordingCompactInputStrategy(recorder: recorder)
        )
        let messages = [
            ChatMessage.text(role: .user, content: "MARKER_DROP_ME"),
        ] + (0..<7).map { _ in
            ChatMessage.text(role: .user, content: String(repeating: "z", count: 400))
        }
        let preference = SettingsContextCompactionPreference(
            isEnabled: true,
            triggerThresholdPercent: 50,
            minRecentMessages: 2
        )

        _ = try await engine.compactIfNeeded(
            messages: messages,
            contextLength: 100,
            preference: preference
        )

        #expect(!recorder.compactInput.isEmpty)
        #expect(!recorder.compactInput.contains { message in
            if case let .text(text) = message { return text.content == "MARKER_DROP_ME" }
            return false
        })
    }
}

private final class SettingsCompactionSummarizeRecorder: SettingsContextCompactionSummarizing, @unchecked Sendable {
    private let lock = NSLock()
    private var _compactInput: [ChatMessage] = []

    var compactInput: [ChatMessage] {
        lock.lock()
        defer { lock.unlock() }
        return _compactInput
    }

    func recordCompactInput(_ messages: [ChatMessage]) {
        lock.lock()
        _compactInput = messages
        lock.unlock()
    }

    func summarize(messages: [ChatMessage]) async throws -> String {
        "short summary"
    }
}
