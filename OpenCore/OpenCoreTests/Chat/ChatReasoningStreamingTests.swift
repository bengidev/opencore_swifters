import Foundation
import Testing

@testable import OpenCore

/// Reasoning-stream regression tests for `ChatFlowController`.
@MainActor
@Suite("Chat Reasoning Streaming")
struct ChatReasoningStreamingTests {
    private func thinkingMessages(_ state: ChatFlowState) -> [ChatThinkingMessage] {
        state.messages.compactMap {
            if case let .thinking(message) = $0 { return message }
            return nil
        }
    }

    private func assistantText(_ state: ChatFlowState) -> String {
        state.messages.reversed().compactMap {
            if case let .text(message) = $0, message.role == .assistant { return message.content }
            return nil
        }.first ?? ""
    }

    private func makeController(
        events: [ChatStreamingEvent],
        ids: [UUID] = (0..<20).map { i in
            var bytes = [UInt8](repeating: 0, count: 16)
            bytes[15] = UInt8(i)
            return UUID(uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3],
                bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11],
                bytes[12], bytes[13], bytes[14], bytes[15]
            ))
        }
    ) -> ChatFlowController {
        let preference = SidePanelInMemoryProviderPreferenceStore(
            preference: SidePanelProviderPreference(
                providerID: ProviderDescriptor.openRouter.id,
                modelID: "meta-llama/llama-3.3-70b-instruct:free"
            )
        )
        var idIndex = 0
        return ChatFlowController(
            streaming: ChatCannedEventClient(events: events).asStreamingClient,
            providerPreference: preference,
            makeID: {
                defer { idIndex += 1 }
                return ids[idIndex % ids.count]
            },
            now: { Date(timeIntervalSince1970: 0) }
        )
    }

    @Test("Late reasoning delta merges into existing reasoning row")
    func lateReasoningDeltaDoesNotSpawnExtraRow() async {
        let controller = makeController(events: [
            .thinkingDelta("Weighing "),
            .thinkingDelta("options. "),
            .textDelta("Answer "),
            .thinkingDelta("(extra note) "),
            .textDelta("final."),
            .done
        ])

        controller.setDraftMessage("Hello")
        await controller.sendMessage()

        let thinking = thinkingMessages(controller.state)
        #expect(thinking.count == 1)
        #expect(thinking.first?.content == "Weighing options. (extra note) ")
        #expect(thinking.first?.isComplete == true)
        #expect(assistantText(controller.state) == "Answer final.")

        let reasoningIndex = controller.state.messages.firstIndex { if case .thinking = $0 { return true }; return false }
        let answerIndex = controller.state.messages.firstIndex {
            if case let .text(m) = $0, m.role == .assistant { return true }; return false
        }
        #expect(reasoningIndex != nil && answerIndex != nil)
        #expect((reasoningIndex ?? 0) < (answerIndex ?? 0))
    }

    @Test("Done without answer after reasoning surfaces an error")
    func reasoningOnlyTurnShowsError() async {
        let controller = makeController(events: [
            .thinkingDelta("Only reasoning."),
            .done
        ])

        controller.setDraftMessage("Q")
        await controller.sendMessage()

        #expect(thinkingMessages(controller.state).count == 1)
        #expect(assistantText(controller.state).isEmpty)
        #expect(controller.state.streamingStatus == .failed)
        #expect(controller.state.streamErrorMessage?.contains("did not return an answer") == true)
        #expect(!controller.state.showsStreamingStatusCapsule)
    }

    @Test("Done finalizes reasoning row")
    func doneFinalizesReasoning() async {
        let controller = makeController(events: [
            .thinkingDelta("thinking…"),
            .textDelta("ok"),
            .done
        ])

        controller.setDraftMessage("Test")
        await controller.sendMessage()

        let thinking = thinkingMessages(controller.state)
        #expect(thinking.count == 1)
        #expect(thinking.allSatisfy { $0.isComplete })
        #expect(controller.state.streamingStatus == .done)
    }

    @Test("Whitespace-only reasoning does not create thinking row")
    func whitespaceReasoningSkipped() async {
        let controller = makeController(events: [
            .thinkingDelta("   "),
            .thinkingDelta("\n"),
            .textDelta("answer"),
            .done
        ])

        controller.setDraftMessage("Q")
        await controller.sendMessage()

        #expect(thinkingMessages(controller.state).isEmpty)
        #expect(assistantText(controller.state) == "answer")
    }
}
