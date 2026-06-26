import Foundation
import Testing

@testable import OpenCore

@Suite("Settings Context Compaction Trim Strategy")
struct SettingsContextCompactionTrimStrategyTests {
    private let strategy = SettingsContextCompactionTrimStrategy()
    private let contextLength = 100

    @Test("Preserves trailing recent messages")
    func preservesRecentMessages() async throws {
        let messages = (0..<8).map { index in
            ChatMessage.text(role: index.isMultiple(of: 2) ? .user : .assistant, content: String(repeating: "a", count: 80))
        }

        let compacted = try await strategy.compact(
            messages: messages,
            contextLength: contextLength,
            thresholdPercent: 50,
            minRecentMessages: 4
        )

        #expect(compacted.count >= 4)
        #expect(compacted.suffix(4).map(\.id) == messages.suffix(4).map(\.id))
    }

    @Test("Reduces usage below threshold when possible")
    func reducesUsageBelowThreshold() async throws {
        let messages = (0..<10).map { _ in
            ChatMessage.text(role: .user, content: String(repeating: "z", count: 120))
        }

        let compacted = try await strategy.compact(
            messages: messages,
            contextLength: contextLength,
            thresholdPercent: 50,
            minRecentMessages: 2
        )

        let usage = ContextWindowEstimator.estimate(
            messages: compacted,
            draft: nil,
            contextLength: contextLength
        )
        #expect(usage.fractionUsed < 0.5 || compacted.count == 2)
    }
}
