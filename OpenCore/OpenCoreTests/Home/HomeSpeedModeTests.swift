import Foundation
import Testing

@testable import OpenCore

@MainActor
@Suite("Home Speed Mode")
struct HomeSpeedModeTests {
    @Test("Router models expose standard and fast speed modes")
    func routerModelHasSpeedModes() {
        let option = HomeModelOption(
            model: ChatModel(
                id: "openrouter/free",
                displayName: "Free Models Router",
                isFree: true,
                supportsSpeedModes: true
            )
        )

        #expect(option.availableSpeedModes == [.standard, .fast])
    }

    @Test("Standard models hide the speed chip")
    func standardModelHidesSpeedModes() {
        let option = HomeModelOption(
            model: ChatModel(
                id: "meta-llama/llama-3.3-70b-instruct:free",
                displayName: "Llama 3.3 70B",
                isFree: true
            )
        )

        #expect(option.availableSpeedModes.isEmpty)
    }

    @Test("Model selection resets unsupported speed mode")
    func selectModelResetsUnsupportedSpeed() {
        let home = HomeFlowController(
            state: HomeFlowState(speedMode: .fast),
            credentialStore: SidePanelInMemoryCredentialStore(),
            providerPreference: SidePanelInMemoryProviderPreferenceStore()
        )

        home.selectModel("meta-llama/llama-3.3-70b-instruct:free")

        #expect(home.state.speedMode == .standard)
    }

    @Test("Fast mode maps to OpenRouter throughput routing")
    func fastModeProviderSort() {
        #expect(HomeComposerSpeedMode.fast.providerSortBy == "throughput")
        #expect(HomeComposerSpeedMode.standard.providerSortBy == nil)
    }

    @Test("Fast requests include provider routing payload")
    func fastRequestIncludesProviderRouting() throws {
        let request = try ChatOpenAICompatibleStreamingClient.makeURLRequest(
            provider: .openRouter,
            secret: "test-key",
            chatRequest: ChatRequest(
                conversationID: UUID(),
                messages: [.text(id: UUID(), role: .user, content: "Hi", timestamp: .init())],
                provider: .openRouter,
                modelID: "openrouter/free",
                speedMode: .fast
            )
        )

        let body = try JSONDecoder().decode(RequestProbe.self, from: request.httpBody ?? Data())
        #expect(body.provider?.sort.by == "throughput")
        #expect(body.provider?.sort.partition == "none")
    }
}

private nonisolated struct RequestProbe: Decodable {
    struct Provider: Decodable {
        struct Sort: Decodable {
            let by: String
            let partition: String
        }

        let sort: Sort
    }

    let provider: Provider?
}
