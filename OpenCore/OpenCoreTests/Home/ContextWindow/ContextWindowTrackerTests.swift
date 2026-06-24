import Foundation
import Testing

@testable import OpenCore

@Suite("Context Window Tracker")
struct ContextWindowTrackerTests {
    private func message(withTokenCount count: Int) -> ChatMessage {
        let content = String(repeating: "a", count: count * 4)
        return .text(role: .user, content: content)
    }

    @Test("Refresh updates usage from messages and model limit")
    func refreshUpdatesUsageFromMessagesAndLimit() {
        var tracker = ContextWindowTracker()
        let messages = [message(withTokenCount: 1_000)]

        tracker.refresh(messages: messages, draft: nil, contextLength: 100_000)

        #expect(tracker.usage.tokensUsed == 1_000)
        #expect(tracker.usage.tokenLimit == 100_000)
        #expect(tracker.usage.fractionUsed == 0.01)
    }

    @Test("Model change updates token limit while preserving message load")
    func modelChangeUpdatesLimitPreservesMessageLoad() {
        var tracker = ContextWindowTracker()
        let messages = [message(withTokenCount: 1_000)]

        tracker.refresh(messages: messages, draft: nil, contextLength: 100_000)
        let usedBeforeModelChange = tracker.usage.tokensUsed
        let fractionBeforeModelChange = tracker.usage.fractionUsed

        tracker.refresh(messages: messages, draft: nil, contextLength: 200_000)

        #expect(tracker.usage.tokensUsed == usedBeforeModelChange)
        #expect(tracker.usage.tokenLimit == 200_000)
        #expect(tracker.usage.fractionUsed == fractionBeforeModelChange / 2)
    }
}
