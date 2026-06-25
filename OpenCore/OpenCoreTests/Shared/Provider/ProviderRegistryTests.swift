import Foundation
import Testing

@testable import OpenCore

@Suite("Provider Registry")
struct ProviderRegistryTests {
    private func sampleChatRequest(
        modelID: String = "glm-5",
        reasoningEffort: String? = "high",
        providerSortBy: String? = nil
    ) -> ChatRequest {
        ChatRequest(
            conversationID: UUID(),
            messages: [.text(id: UUID(), role: .user, content: "Hi", timestamp: .init())],
            providerID: ProviderDescriptor.openRouter.id,
            modelID: modelID,
            reasoningEffort: reasoningEffort,
            providerSortBy: providerSortBy
        )
    }

    @Test("ProviderRegistry.resolve returns OpenRouter adapter for openrouter id")
    func resolveReturnsOpenRouterAdapter() {
        let adapter = ProviderRegistry.resolve(id: "openrouter")

        #expect(adapter is ProviderOpenRouterAdapter)
        #expect(adapter.descriptor.id == "openrouter")
    }

    @Test("ProviderRegistry.resolve falls back to default for unknown id")
    func resolveFallsBackToDefaultForUnknownId() {
        #expect(ProviderRegistry.resolve(id: "unknown").descriptor.id == ProviderRegistry.defaultAdapter.descriptor.id)
        #expect(ProviderRegistry.resolve(id: nil).descriptor.id == "openrouter")
    }

    @Test("ProviderRegistry.all contains four providers")
    func allContainsFourProviders() {
        #expect(ProviderRegistry.all.count == 4)
        #expect(
            Set(ProviderRegistry.all.map(\.descriptor.id)) == ["openrouter", "opencode", "commandcode", "ollama"]
        )
    }

    @Test("OpenRouter adapter supports provider routing")
    func openRouterSupportsProviderRouting() {
        let adapter = ProviderRegistry.resolve(id: "openrouter")

        #expect(adapter.supportsProviderRouting)
    }

    @Test("OpenCode adapter uses top-level reasoning_effort")
    func openCodeUsesTopLevelReasoningEffort() throws {
        let adapter = ProviderRegistry.resolve(id: "opencode")
        let request = try adapter.makeChatCompletionURLRequest(
            secret: "test-key",
            chatRequest: sampleChatRequest(modelID: "glm-5", reasoningEffort: "high")
        )

        let body = try JSONDecoder().decode(ReasoningProbe.self, from: request.httpBody ?? Data())
        #expect(body.reasoning == nil)
        #expect(body.reasoningEffort == "high")
    }

    @Test("OpenRouter adapter uses nested reasoning object")
    func openRouterUsesNestedReasoningObject() throws {
        let adapter = ProviderRegistry.resolve(id: "openrouter")
        let request = try adapter.makeChatCompletionURLRequest(
            secret: "test-key",
            chatRequest: sampleChatRequest(modelID: "openrouter/free", reasoningEffort: "high")
        )

        let body = try JSONDecoder().decode(ReasoningProbe.self, from: request.httpBody ?? Data())
        #expect(body.reasoning?.effort == "high")
        #expect(body.reasoningEffort == nil)
    }

    @Test("ProviderRegistry adapter descriptor ids match expected values")
    func descriptorIdsMatchExpectedValues() {
        let expected: [String: String] = [
            "openrouter": "OpenRouter",
            "opencode": "OpenCode",
            "commandcode": "Command Code",
            "ollama": "Ollama Cloud"
        ]

        #expect(Set(ProviderRegistry.all.map(\.descriptor.id)) == Set(expected.keys))
        for adapter in ProviderRegistry.all {
            #expect(expected[adapter.descriptor.id] == adapter.descriptor.displayName)
        }
    }
}

private nonisolated struct ReasoningProbe: Decodable {
    struct Reasoning: Decodable {
        let effort: String
    }

    let reasoning: Reasoning?
    let reasoningEffort: String?

    enum CodingKeys: String, CodingKey {
        case reasoning
        case reasoningEffort = "reasoning_effort"
    }
}
