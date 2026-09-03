import Foundation
import Testing

@testable import OpenCore

@Suite("Chat Context Overflow Detector")
struct ChatContextOverflowDetectorTests {
    @Test("Detects common provider overflow messages")
    func detectsOverflowMessages() {
        #expect(ChatContextOverflowDetector.isContextOverflow("maximum context length exceeded"))
        #expect(ChatContextOverflowDetector.isContextOverflow("Prompt is too long for this model"))
        #expect(!ChatContextOverflowDetector.isContextOverflow("Cannot connect to model."))
    }
}
