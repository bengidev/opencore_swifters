import Foundation
import Testing

@testable import OpenCore

@Suite("Context Window Estimator")
struct ContextWindowEstimatorTests {
    private func estimatedTokens(for text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        return (trimmed.count + 3) / 4
    }

    @Test("Empty messages and no draft yield zero used with known limit")
    func emptyConversationWithKnownLimit() {
        let usage = ContextWindowEstimator.estimate(
            messages: [],
            draft: nil,
            contextLength: 258_000
        )

        #expect(usage.tokensUsed == 0)
        #expect(usage.tokenLimit == 258_000)
        #expect(usage.fractionUsed == 0)
    }

    @Test("Whitespace-only draft is ignored")
    func whitespaceDraftIgnored() {
        let usage = ContextWindowEstimator.estimate(
            messages: [],
            draft: "   \n\t  ",
            contextLength: 258_000
        )

        #expect(usage.tokensUsed == 0)
    }

    @Test("Messages contribute to estimated used tokens")
    func messagesContributeToUsedTokens() {
        let userText = "Hello from the user"
        let assistantText = "Hi"
        let usage = ContextWindowEstimator.estimate(
            messages: [
                .text(role: .user, content: userText),
                .text(role: .assistant, content: assistantText),
            ],
            draft: nil,
            contextLength: 131_072
        )

        let expectedUsed = estimatedTokens(for: userText) + estimatedTokens(for: assistantText)
        #expect(usage.tokensUsed == expectedUsed)
        #expect(usage.tokenLimit == 131_072)
        #expect(usage.fractionUsed == Double(expectedUsed) / 131_072)
    }

    @Test("Draft message is included in estimate")
    func draftIncludedInEstimate() {
        let messageText = "Hi"
        let draftText = "Hello"
        let usage = ContextWindowEstimator.estimate(
            messages: [.text(role: .user, content: messageText)],
            draft: draftText,
            contextLength: 100_000
        )

        let expectedUsed = estimatedTokens(for: messageText) + estimatedTokens(for: draftText)
        #expect(usage.tokensUsed == expectedUsed)
    }

    @Test("Thinking messages are counted toward usage")
    func thinkingMessagesCounted() {
        let thinkingText = "Reasoning here"
        let answerText = "Answer"
        let usage = ContextWindowEstimator.estimate(
            messages: [
                .thinking(content: thinkingText),
                .text(role: .assistant, content: answerText),
            ],
            draft: nil,
            contextLength: 163_840
        )

        let expectedUsed = estimatedTokens(for: thinkingText) + estimatedTokens(for: answerText)
        #expect(usage.tokensUsed == expectedUsed)
    }

    @Test("Model context length sets token limit")
    func modelContextLengthSetsTokenLimit() {
        let usage = ContextWindowEstimator.estimate(
            messages: [.text(role: .user, content: "Ping")],
            draft: nil,
            contextLength: 200_000
        )

        #expect(usage.tokenLimit == 200_000)
    }

    @Test("Nil model context length yields unknown limit")
    func nilContextLengthYieldsUnknownLimit() {
        let usage = ContextWindowEstimator.estimate(
            messages: [.text(role: .user, content: "Ping")],
            draft: nil,
            contextLength: nil
        )

        #expect(usage.tokenLimit == 0)
        #expect(usage.fractionUsed == 0)
    }

    @Test("Incomplete assistant and thinking messages are excluded")
    func incompleteMessagesExcluded() {
        let completeText = "Done"
        let streamingText = String(repeating: "x", count: 400)
        let usage = ContextWindowEstimator.estimate(
            messages: [
                .text(role: .user, content: completeText),
                .text(role: .assistant, content: streamingText, isComplete: false),
                .thinking(content: streamingText, isComplete: false),
            ],
            draft: nil,
            contextLength: 100_000
        )

        #expect(usage.tokensUsed == estimatedTokens(for: completeText))
    }
}
