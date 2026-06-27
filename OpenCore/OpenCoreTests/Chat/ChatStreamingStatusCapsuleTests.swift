import Foundation
import Testing

@testable import OpenCore

@MainActor
@Suite("Chat Streaming Status Capsule State")
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

    @Test("Capsule visibility tracks sending and streaming status", arguments: [
        (true, ChatStreamingStatus.running, true),
        (false, ChatStreamingStatus.running, false),
        (true, ChatStreamingStatus.idle, false),
        (false, ChatStreamingStatus.idle, false)
    ])
    func capsuleVisibility(
        isSending: Bool,
        streamingStatus: ChatStreamingStatus,
        expected: Bool
    ) {
        let state = ChatFlowState(isSending: isSending, streamingStatus: streamingStatus)
        #expect(state.showsStreamingStatusCapsule == expected)
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
