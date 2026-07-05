import Foundation
import Testing

@testable import OpenCore

@Suite("Chat Thread Scroll Target")
struct ChatThreadScrollTargetTests {
    private let userID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let assistantID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let followUpUserID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    private let thinkingID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
    private let answerID = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
    private let outputStreamID = UUID(uuidString: "00000000-0000-0000-0000-000000000006")!

    @Test("Follow-up user message scrolls to the new bubble")
    func followUpUserMessage() {
        let messages: [ChatMessage] = [
            .text(id: userID, role: .user, content: "First"),
            .text(id: assistantID, role: .assistant, content: "Reply"),
            .text(id: followUpUserID, role: .user, content: "Second"),
        ]

        #expect(ChatThreadScrollTarget.messageID(in: messages) == followUpUserID)
    }

    @Test("Current turn prefers assistant answer over thinking card")
    func prefersAssistantAnswerOverThinking() {
        let messages: [ChatMessage] = [
            .text(id: userID, role: .user, content: "Question"),
            .thinking(id: thinkingID, content: "Reasoning…"),
            .text(id: answerID, role: .assistant, content: "Answer", isComplete: false),
        ]

        #expect(ChatThreadScrollTarget.messageID(in: messages) == answerID)
    }

    @Test("Current turn prefers output stream over thinking card")
    func prefersOutputStreamOverThinking() {
        let messages: [ChatMessage] = [
            .text(id: userID, role: .user, content: "Question"),
            .thinking(id: thinkingID, content: "Reasoning…"),
            .outputStream(id: outputStreamID, command: "run", detail: ChatOutputStreamDetail(outputTail: "Running…")),
        ]

        #expect(ChatThreadScrollTarget.messageID(in: messages) == outputStreamID)
    }

    @Test("Thinking-only turn scrolls to the thinking card")
    func thinkingOnlyTurn() {
        let messages: [ChatMessage] = [
            .text(id: userID, role: .user, content: "Question"),
            .thinking(id: thinkingID, content: "Reasoning…", isComplete: false),
        ]

        #expect(ChatThreadScrollTarget.messageID(in: messages) == thinkingID)
    }

    @Test("Completed assistant reply scrolls to assistant text")
    func completedAssistantReply() {
        let messages: [ChatMessage] = [
            .text(id: userID, role: .user, content: "Question"),
            .text(id: assistantID, role: .assistant, content: "Reply"),
        ]

        #expect(ChatThreadScrollTarget.messageID(in: messages) == assistantID)
    }
}
