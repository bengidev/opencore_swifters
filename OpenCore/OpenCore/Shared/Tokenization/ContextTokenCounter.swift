import Foundation
import os
import Tiktoken

/// Tiktoken-backed token counting with a character heuristic fallback before warm-up or on failure.
nonisolated enum ContextTokenCounter {
    private final class EncodingBox: @unchecked Sendable {
        let value: Encoding
        init(_ value: Encoding) { self.value = value }
    }

    private static let encodingState = OSAllocatedUnfairLock<EncodingBox?>(initialState: nil)

    /// Loads the default OpenAI-compatible encoder (`cl100k_base` via gpt-4).
    static func warmUp() async {
        let alreadyLoaded = encodingState.withLock { $0 != nil }
        guard !alreadyLoaded else { return }
        guard let loaded = try? await Tiktoken.shared.getEncoding("gpt-4") else { return }
        let box = EncodingBox(loaded)
        encodingState.withLock { $0 = box }
    }

    static func installEncoderForTesting(_ testEncoder: Encoding?) {
        let box = testEncoder.map(EncodingBox.init)
        encodingState.withLock { $0 = box }
    }

    static func countTokens(in text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }

        return encodingState.withLock { state in
            if let activeEncoder = state?.value {
                return activeEncoder.encode(value: trimmed).count
            }
            return heuristicTokenCount(for: trimmed)
        }
    }

    static func countTokens(for message: ChatMessage) -> Int {
        countTokens(in: messageText(message))
    }

    static func countTokens(for messages: [ChatMessage], draft: String? = nil) -> Int {
        var total = messages.reduce(0) { $0 + countTokens(for: $1) }
        if let draft {
            total += countTokens(in: draft)
        }
        return total
    }

    static func heuristicTokenCount(for text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        return (trimmed.count + 3) / 4
    }

    private static func messageText(_ message: ChatMessage) -> String {
        switch message {
        case let .text(textMessage):
            guard textMessage.isComplete else { return "" }
            var text = textMessage.providerContent
            let wireOverhead = ChatMultimodalWireLogic.estimatedWireTokenOverhead(
                for: textMessage.attachments
            )
            if wireOverhead > 0 {
                text += String(repeating: " ", count: wireOverhead * 4)
            }
            return text
        case let .thinking(thinkingMessage):
            guard thinkingMessage.isComplete else { return "" }
            return thinkingMessage.content
        case let .system(systemMessage):
            return systemMessage.content
        case let .outputStream(outputStreamMessage):
            guard outputStreamMessage.isComplete else { return "" }
            return outputStreamMessage.command + "\n" + outputStreamMessage.detail.outputTail
        }
    }
}
