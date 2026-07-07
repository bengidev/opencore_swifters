import Foundation
import Testing

@testable import OpenCore

@Suite("Chat Assistant Content Normalizer")
struct ChatAssistantContentNormalizerTests {
  @Test("Extracts text from JSON content blocks")
  func jsonContentBlocks() {
    let raw = #"[{"type":"text","text":"GeForce is NVIDIA GPUs."}]"#
    let actual = ChatAssistantContentNormalizer.displayText(from: raw)
    #expect(actual == "GeForce is NVIDIA GPUs.")
  }

  @Test("Extracts text from Python-ish content blocks")
  func pythonishContentBlocks() {
    let raw =
      "[{'type': 'text', 'text': \"GeForce is NVIDIA's brand for consumer GPUs.\"}]"
    let actual = ChatAssistantContentNormalizer.displayText(from: raw)
    #expect(actual == "GeForce is NVIDIA's brand for consumer GPUs.")
  }

  @Test("Extracts text from safety-prefixed JSON content blocks")
  func safetyPrefixedJsonContentBlocks() {
    let raw = """
      User Safety: safe
      Response Safety: safe
      [{"type":"text","text":"GeForce is NVIDIA GPUs."}]
      """
    let actual = ChatAssistantContentNormalizer.displayText(from: raw)
    #expect(actual == "GeForce is NVIDIA GPUs.")
  }

  @Test("Passes through normal prose")
  func normalProse() {
    let raw = "GeForce is NVIDIA's brand for consumer GPUs."
    #expect(ChatAssistantContentNormalizer.displayText(from: raw) == raw)
  }

  @Test("Replaces safety-only classifier output")
  func safetyOnlyOutput() {
    let raw = "User Safety: safe\nResponse Safety: safe"
    #expect(ChatAssistantContentNormalizer.isSafetyOnlyOutput(raw))
  }

  @Test("Safety-only output uses fallback message")
  func safetyOnlyFallback() {
    let raw = "User Safety: safe\nResponse Safety: safe"
    #expect(
      ChatAssistantContentNormalizer.displayText(from: raw)
        == ChatAssistantContentNormalizer.safetyOnlyFallback
    )
  }

  @Test("Mixed safety lines and answer strips safety headers")
  func mixedSafetyAndAnswer() {
    let raw = "User Safety: safe\nA computer is a programmable machine."
    #expect(!ChatAssistantContentNormalizer.isSafetyOnlyOutput(raw))
    #expect(ChatAssistantContentNormalizer.displayText(from: raw) == "A computer is a programmable machine.")
  }

  @Test("Unescapes regex-extracted text fields")
  func unescapesRegexExtractedText() {
    let raw = #"[{'type': 'text', 'text': "Line one.\nLine two."}]"#
    #expect(ChatAssistantContentNormalizer.displayText(from: raw) == "Line one.\nLine two.")
  }
}

@Suite("Chat Stream Output Mapping")
struct ChatStreamOutputMappingTests {
    @Test("Maps sideband exec_command events")
    func sidebandExecCommandEvents() {
        let began = #"{"type":"exec_command_begin","command":"npm test","cwd":"/tmp/project"}"#
        #expect(
            ProviderOpenAICompatibleAdapter.mapStreamPayload(began) == [
                .outputStreamBegan(command: "npm test", cwd: "/tmp/project")
            ]
        )

        let delta = #"{"type":"exec_command_output_delta","chunk":"PASS suite\n"}"#
        #expect(
            ProviderOpenAICompatibleAdapter.mapStreamPayload(delta) == [
                .outputStreamDelta("PASS suite\n")
            ]
        )

        let ended = #"{"type":"exec_command_end","status":"completed","exit_code":0,"duration_ms":1200}"#
        #expect(
            ProviderOpenAICompatibleAdapter.mapStreamPayload(ended) == [
                .outputStreamEnded(status: .completed, exitCode: 0, durationMs: 1200)
            ]
        )
    }

    @Test("Maps failed status from non-zero exit code without explicit status")
    func nonZeroExitWithoutExplicitStatus() {
        let ended = #"{"type":"exec_command_end","exit_code":1}"#
        #expect(
            ProviderOpenAICompatibleAdapter.mapStreamPayload(ended) == [
                .outputStreamEnded(status: .failed, exitCode: 1, durationMs: nil)
            ]
        )
    }

    @Test("Maps argv command arrays and nested msg envelopes")
    func argvAndNestedEnvelope() {
        let began = #"{"type":"exec_command_begin","msg":{"command":["echo","ok"],"cwd":"/tmp"}}"#
        #expect(
            ProviderOpenAICompatibleAdapter.mapStreamPayload(began) == [
                .outputStreamBegan(command: "echo ok", cwd: "/tmp")
            ]
        )
    }

    @Test("Maps command output content parts in delta")
    func commandOutputContentParts() {
        let payload = """
        {"choices":[{"delta":{"content":[{"type":"exec_command_begin","command":"git status","cwd":"/repo"},{"type":"exec_command_output_delta","chunk":"clean\\n"}]}}]}
        """
        let events = ProviderOpenAICompatibleAdapter.mapStreamPayload(payload)
        #expect(events == [
            .outputStreamBegan(command: "git status", cwd: "/repo"),
            .outputStreamDelta("clean\n")
        ])
    }

    @Test("End-to-end sideband output stream renders in chat flow")
    @MainActor
    func sidebandOutputStreamInFlow() async {
        let payloads = [
            #"{"type":"exec_command_begin","command":"npm test","cwd":"/tmp/project"}"#,
            #"{"type":"exec_command_output_delta","chunk":"PASS suite\n"}"#,
            #"{"type":"exec_command_end","status":"completed","exit_code":0,"duration_ms":1200}"#,
            #"{"choices":[{"delta":{"content":"All checks passed."}}]}"#,
        ]
        let events: [ChatStreamingEvent] = payloads.compactMap {
            ProviderOpenAICompatibleAdapter.mapStreamPayload($0)
        }.flatMap { $0 } + [.done]

        let preference = SidePanelInMemoryProviderPreferenceStore(
            preference: SidePanelProviderPreference(
                providerID: ProviderDescriptor.openRouter.id,
                modelID: "openrouter/free"
            )
        )
        let controller = ChatFlowController(
            streaming: ChatCannedEventClient(events: events).asStreamingClient,
            providerPreference: preference
        )

        controller.setDraftMessage("Run tests")
        await controller.sendMessage()

        let rows = controller.state.messages.compactMap { message -> ChatOutputStreamMessage? in
            if case let .outputStream(outputStream) = message { return outputStream }
            return nil
        }

        #expect(rows.count == 1)
        #expect(rows.first?.command == "npm test")
        #expect(rows.first?.detail.outputTail == "PASS suite\n")
        #expect(rows.first?.detail.status == .completed)
    }
}

@Suite("Chat Stream Content Mapping")
struct ChatStreamContentMappingTests {
  @Test("Maps string content deltas")
  func stringContent() {
    let payload = #"{"choices":[{"delta":{"content":"Hello"}}]}"#
    let events = ProviderOpenAICompatibleAdapter.mapStreamPayload(payload)
    #expect(events == [.textDelta("Hello")])
  }

  @Test("Maps array content blocks")
  func arrayContent() {
    let payload = #"{"choices":[{"delta":{"content":[{"type":"text","text":"Hi"}]}}]}"#
    let events = ProviderOpenAICompatibleAdapter.mapStreamPayload(payload)
    #expect(events == [.textDelta("Hi")])
  }

  @Test("Maps reasoning_details deltas to thinking")
  func reasoningDetailsDelta() {
    let payload = """
    {"choices":[{"delta":{"reasoning_details":[{"type":"reasoning.text","text":"Step one. "}]}}]}
    """
    let events = ProviderOpenAICompatibleAdapter.mapStreamPayload(payload)
    #expect(events == [.thinkingDelta("Step one. ")])
  }

  @Test("Maps final message content when delta is empty")
  func finalMessageContent() {
    let payload = """
    {"choices":[{"delta":{},"message":{"role":"assistant","content":"Final answer."}}]}
    """
    let events = ProviderOpenAICompatibleAdapter.mapStreamPayload(payload)
    #expect(events == [.textDelta("Final answer.")])
  }

  @Test("Reasoning then answer streams end-to-end")
  @MainActor
  func reasoningThenAnswerInFlow() async {
    let payloads = [
      #"{"choices":[{"delta":{"reasoning":"Analyzing image…"}}]}"#,
      #"{"choices":[{"delta":{"content":"It shows a cat."}}]}"#,
    ]
    let events: [ChatStreamingEvent] = payloads.compactMap {
      ProviderOpenAICompatibleAdapter.mapStreamPayload($0)
    }.flatMap { $0 } + [.done]

    let controller = ChatFlowController(
      streaming: ChatCannedEventClient(events: events).asStreamingClient,
      providerPreference: SidePanelInMemoryProviderPreferenceStore(
        preference: SidePanelProviderPreference(
          providerID: ProviderDescriptor.openRouter.id,
          modelID: "openrouter/free"
        )
      )
    )

    controller.setDraftMessage("What is in this photo?")
    await controller.sendMessage()

    let thinking = controller.state.messages.compactMap { message -> ChatThinkingMessage? in
      if case let .thinking(value) = message { return value }
      return nil
    }
    let answer = controller.state.messages.compactMap { message -> String? in
      if case let .text(text) = message, text.role == .assistant { return text.content }
      return nil
    }.first

    #expect(thinking.count == 1)
    #expect(thinking.first?.content == "Analyzing image…")
    #expect(thinking.first?.isComplete == true)
    #expect(answer == "It shows a cat.")
    #expect(!controller.state.showsStreamingStatusCapsule)
  }

  @Test("End-to-end content block string is normalized in chat flow")
  @MainActor
  func contentBlockStringInFlow() async {
    let raw =
      "[{'type': 'text', 'text': \"GeForce is NVIDIA's brand for consumer GPUs.\"}]"
    let preference = SidePanelInMemoryProviderPreferenceStore(
      preference: SidePanelProviderPreference(
        providerID: ProviderDescriptor.openRouter.id,
        modelID: "openrouter/free"
      )
    )
    let controller = ChatFlowController(
      streaming: ChatCannedEventClient(events: [.textDelta(raw), .done]).asStreamingClient,
      providerPreference: preference
    )

    controller.setDraftMessage("What is GeForce?")
    await controller.sendMessage()

    let assistantText = controller.state.messages.compactMap { message -> String? in
      if case let .text(text) = message, text.role == .assistant { return text.content }
      return nil
    }.first

    #expect(assistantText == "GeForce is NVIDIA's brand for consumer GPUs.")
  }

  @Test("Safety-only classifier output is replaced in chat flow")
  @MainActor
  func safetyOnlyInFlow() async {
    let raw = "User Safety: safe\nResponse Safety: safe"
    let preference = SidePanelInMemoryProviderPreferenceStore(
      preference: SidePanelProviderPreference(
        providerID: ProviderDescriptor.openRouter.id,
        modelID: "openrouter/free"
      )
    )
    let controller = ChatFlowController(
      streaming: ChatCannedEventClient(events: [.textDelta(raw), .done]).asStreamingClient,
      providerPreference: preference
    )

    controller.setDraftMessage("What is computers?")
    await controller.sendMessage()

    let assistantText = controller.state.messages.compactMap { message -> String? in
      if case let .text(text) = message, text.role == .assistant { return text.content }
      return nil
    }.first

    #expect(assistantText == ChatAssistantContentNormalizer.safetyOnlyFallback)
  }

  @Test("Combined safety headers and JSON blocks normalize after stream completes")
  @MainActor
  func safetyPrefixedJsonInFlow() async {
    let deltas = [
      "User Safety: safe\n",
      "Response Safety: safe\n",
      #"[{"type":"text","text":"GeForce is NVIDIA GPUs."}]"#,
    ]
    let events: [ChatStreamingEvent] = deltas.map { .textDelta($0) } + [.done]
    let preference = SidePanelInMemoryProviderPreferenceStore(
      preference: SidePanelProviderPreference(
        providerID: ProviderDescriptor.openRouter.id,
        modelID: "openrouter/free"
      )
    )
    let controller = ChatFlowController(
      streaming: ChatCannedEventClient(events: events).asStreamingClient,
      providerPreference: preference
    )

    controller.setDraftMessage("What is GeForce?")
    await controller.sendMessage()

    let assistantText = controller.state.messages.compactMap { message -> String? in
      if case let .text(text) = message, text.role == .assistant { return text.content }
      return nil
    }.first

    #expect(assistantText == "GeForce is NVIDIA GPUs.")
  }
}
