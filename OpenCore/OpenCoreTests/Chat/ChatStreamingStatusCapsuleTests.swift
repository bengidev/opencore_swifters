import Foundation
import Testing

@testable import OpenCore

@MainActor
@Suite("Chat Streaming Status Capsule")
struct ChatStreamingStatusCapsuleTests {
    private func makeController(events: [ChatStreamingEvent]) -> ChatFlowController {
        let preference = SidePanelInMemoryProviderPreferenceStore(
            preference: SidePanelProviderPreference(
                providerID: ProviderDescriptor.openRouter.id,
                modelID: "meta-llama/llama-3.3-70b-instruct:free"
            )
        )
        return ChatFlowController(
            streaming: ChatCannedEventClient(events: events).asStreamingClient,
            providerPreference: preference
        )
    }

    @Test("Capsule visible while sending and streaming")
    func visibleWhileStreaming() {
        var state = ChatFlowState(isSending: true, streamingStatus: .running)
        #expect(state.showsStreamingStatusCapsule)
    }

    @Test("Capsule hidden when idle")
    func hiddenWhenIdle() {
        var state = ChatFlowState()
        #expect(!state.showsStreamingStatusCapsule)
    }

    @Test("Capsule hidden after stream completes")
    func hiddenAfterStreamCompletes() async {
        let controller = makeController(events: [
            .textDelta("Answer"),
            .done
        ])
        controller.setDraftMessage("Q")
        await controller.sendMessage()
        #expect(!controller.state.showsStreamingStatusCapsule)
    }
}
