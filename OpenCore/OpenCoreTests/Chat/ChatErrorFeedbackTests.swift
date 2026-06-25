import Foundation
import Testing

@testable import OpenCore

@MainActor
@Suite("Chat Error Feedback")
struct ChatErrorFeedbackTests {
    private final class AttemptQueue: @unchecked Sendable {
        private var scripts: [[ChatStreamingEvent]]
        private let lock = NSLock()

        init(_ scripts: [[ChatStreamingEvent]]) {
            self.scripts = scripts
        }

        func next() -> [ChatStreamingEvent] {
            lock.lock()
            defer { lock.unlock() }
            return scripts.isEmpty ? [] : scripts.removeFirst()
        }
    }

    private func makeController(
        events: [ChatStreamingEvent],
        secondAttempt: [ChatStreamingEvent] = []
    ) -> ChatFlowController {
        let queue = AttemptQueue([events, secondAttempt])
        let preference = SidePanelInMemoryProviderPreferenceStore(
            preference: SidePanelProviderPreference(
                providerID: ProviderDescriptor.openRouter.id,
                modelID: "meta-llama/llama-3.3-70b-instruct:free"
            )
        )
        return ChatFlowController(
            streaming: ChatStreamingClient(stream: { _ in
                let script = queue.next()
                return AsyncStream { continuation in
                    for event in script { continuation.yield(event) }
                    continuation.finish()
                }
            }),
            providerPreference: preference,
            now: { Date(timeIntervalSince1970: 0) }
        )
    }

    @Test("A connection failure surfaces a visible error in state")
    func failureSurfacesError() async {
        let controller = makeController(events: [.error("Cannot connect to model.")])

        controller.setDraftMessage("Hello")
        await controller.sendMessage()

        #expect(controller.state.streamingStatus == .failed)
        #expect(controller.state.streamErrorMessage == "Cannot connect to model.")
        #expect(controller.state.isSending == false)
        #expect(controller.state.messages.count == 1)
        #expect(controller.state.messages.first?.role == .user)
    }

    @Test("Dismiss clears the error state")
    func dismissClearsError() async {
        let controller = makeController(events: [.error("boom")])

        controller.setDraftMessage("Hi")
        await controller.sendMessage()
        controller.dismissError()

        #expect(controller.state.streamErrorMessage == nil)
        #expect(controller.state.streamingStatus == .idle)
    }

    @Test("Retry re-issues without appending a new user message")
    func retryReissuesRequest() async {
        let controller = makeController(
            events: [.error("fail")],
            secondAttempt: [.textDelta("ok"), .done]
        )

        controller.setDraftMessage("Hello")
        await controller.sendMessage()
        #expect(controller.state.messages.count == 1)

        await controller.retry()

        #expect(controller.state.messages.count == 2)
        #expect(controller.state.streamingStatus == .done)
        #expect(controller.state.messages.last?.role == .assistant)
    }
}
