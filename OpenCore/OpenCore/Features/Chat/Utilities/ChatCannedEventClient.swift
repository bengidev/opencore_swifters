import Foundation

/// Replays a fixed script of streaming events for tests and previews.
nonisolated struct ChatCannedEventClient: Sendable {
    let events: [ChatStreamingEvent]

    init(events: [ChatStreamingEvent]) {
        self.events = events
    }

    init() {
        self.events = Self.defaultScript
    }

    func stream(request: ChatRequest) -> AsyncStream<ChatStreamingEvent> {
        let events = self.events
        return AsyncStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }

    /// Yields `events` then keeps the stream open until the consumer task is cancelled.
    func streamHangingAfterEvents(request: ChatRequest) -> AsyncStream<ChatStreamingEvent> {
        let events = self.events
        return AsyncStream { continuation in
            for event in events {
                continuation.yield(event)
            }
        }
    }

    var asStreamingClient: ChatStreamingClient {
        ChatStreamingClient(stream: stream(request:))
    }

    var asHangingStreamingClient: ChatStreamingClient {
        ChatStreamingClient(stream: streamHangingAfterEvents(request:))
    }
}

extension ChatCannedEventClient {
    nonisolated static let defaultScript: [ChatStreamingEvent] = [
        .thinkingDelta("Weighing "),
        .thinkingDelta("options. "),
        .textDelta("Here is "),
        .thinkingDelta("(one more note) "),
        .textDelta("the answer."),
        .done
    ]
}
