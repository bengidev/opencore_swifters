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

  @Test("Mixed safety lines and answer is not treated as safety-only")
  func mixedSafetyAndAnswer() {
    let raw = "User Safety: safe\nA computer is a programmable machine."
    #expect(!ChatAssistantContentNormalizer.isSafetyOnlyOutput(raw))
    #expect(ChatAssistantContentNormalizer.displayText(from: raw) == raw)
  }
}

@Suite("Chat Stream Content Mapping")
struct ChatStreamContentMappingTests {
  @Test("Maps string content deltas")
  func stringContent() {
    let payload = #"{"choices":[{"delta":{"content":"Hello"}}]}"#
    let events = ChatOpenAICompatibleStreamingClient.mapDataPayload(payload)
    #expect(events == [.textDelta("Hello")])
  }

  @Test("Maps array content blocks")
  func arrayContent() {
    let payload = #"{"choices":[{"delta":{"content":[{"type":"text","text":"Hi"}]}}]}"#
    let events = ChatOpenAICompatibleStreamingClient.mapDataPayload(payload)
    #expect(events == [.textDelta("Hi")])
  }

  @Test("End-to-end content block string is normalized in chat flow")
  @MainActor
  func contentBlockStringInFlow() async {
    let raw =
      "[{'type': 'text', 'text': \"GeForce is NVIDIA's brand for consumer GPUs.\"}]"
    let preference = SidePanelInMemoryProviderPreferenceStore(
      preference: SidePanelProviderPreference(
        providerID: SidePanelProviderAPI.openRouter.id,
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
        providerID: SidePanelProviderAPI.openRouter.id,
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
}
