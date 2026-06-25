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
            state: HomeFlowState(
                speedMode: .fast,
                catalogModels: HomeTestCatalog.sampleModels
            ),
            credentialStore: CredentialInMemoryStore(),
            providerPreference: SidePanelInMemoryProviderPreferenceStore()
        )

        home.selectModel("meta-llama/llama-3.3-70b-instruct:free")

        #expect(home.state.speedMode == .standard)
    }

    @Test("Unsupported speed mode selection is ignored")
    func selectUnsupportedSpeedModeIgnored() {
        let home = HomeFlowController(
            state: HomeFlowState(
                selectedModelID: "meta-llama/llama-3.3-70b-instruct:free",
                speedMode: .standard,
                catalogModels: HomeTestCatalog.sampleModels
            ),
            credentialStore: CredentialInMemoryStore(),
            providerPreference: SidePanelInMemoryProviderPreferenceStore()
        )

        home.selectSpeedMode(.fast)

        #expect(home.state.speedMode == .standard)
    }

    @Test("Fast mode maps to OpenRouter throughput routing")
    func fastModeProviderSort() {
        #expect(HomeComposerSpeedMode.fast.providerSortBy == "throughput")
        #expect(HomeComposerSpeedMode.standard.providerSortBy == nil)
    }

    @Test("Active provider sort is nil for unsupported models")
    func activeProviderSortNilForStandardModel() {
        var state = HomeFlowState(speedMode: .fast)
        state.catalogModels = HomeTestCatalog.sampleModels
        state.selectedModelID = "meta-llama/llama-3.3-70b-instruct:free"

        #expect(state.activeProviderSortBy == nil)
    }

    @Test("Active provider sort forwards fast mode for router models")
    func activeProviderSortForRouterModel() {
        var state = HomeFlowState(speedMode: .fast)
        state.catalogModels = [
            ChatModel(
                id: "openrouter/free",
                displayName: "Free Models Router",
                isFree: true,
                supportsSpeedModes: true
            )
        ]
        state.selectedModelID = "openrouter/free"

        #expect(state.activeProviderSortBy == "throughput")
    }

    @Test("Catalog router entry enables speed modes")
    func catalogRouterEntryEnablesSpeedModes() throws {
        let json = Data("""
        {"id":"openrouter/free","name":"Free Models Router","architecture":{"tokenizer":"Router"}}
        """.utf8)

        let model = try HomeModelCatalogClient.chatModel(fromCatalogEntryJSON: json)

        #expect(model.supportsSpeedModes)
    }

    @Test("Catalog standard entry hides speed modes")
    func catalogStandardEntryHidesSpeedModes() throws {
        let json = Data("""
        {"id":"meta-llama/llama-3.3-70b-instruct:free","name":"Llama 3.3 70B","architecture":{"tokenizer":"Llama3"}}
        """.utf8)

        let model = try HomeModelCatalogClient.chatModel(fromCatalogEntryJSON: json)

        #expect(!model.supportsSpeedModes)
    }

    @Test("Catalog entry exposes reasoning from supported parameters")
    func catalogReasoningFromSupportedParameters() throws {
        let json = Data("""
        {"id":"vendor/model","name":"Reasoning Model","supported_parameters":["reasoning"],"architecture":{"modality":"text->text"}}
        """.utf8)

        let model = try HomeModelCatalogClient.chatModel(fromCatalogEntryJSON: json)

        #expect(model.supportsReasoning)
        #expect(!model.supportedReasoningEfforts.isEmpty)
    }

    @Test("Catalog entry parses supported reasoning efforts")
    func catalogParsesSupportedReasoningEfforts() throws {
        let json = Data("""
        {"id":"openai/o4-mini","name":"O4 Mini","supported_parameters":["reasoning"],"reasoning":{"supported_efforts":["high","medium","low","none"],"mandatory":false}}
        """.utf8)

        let model = try HomeModelCatalogClient.chatModel(fromCatalogEntryJSON: json)

        #expect(model.supportedReasoningEfforts == ["high", "medium", "low", "none"])
        #expect(!model.reasoningMandatory)
    }

    @Test("Catalog provider parameter enables speed modes")
    func catalogProviderParameterEnablesSpeedModes() throws {
        let json = Data("""
        {"id":"vendor/router","name":"Router","supported_parameters":["provider"]}
        """.utf8)

        let model = try HomeModelCatalogClient.chatModel(fromCatalogEntryJSON: json)

        #expect(model.supportsSpeedModes)
    }

    @Test("Non-router provider hides speed modes for router-capable models")
    func nonRouterProviderHidesSpeedModes() {
        let option = HomeModelOption(
            model: ChatModel(
                id: "openrouter/free",
                displayName: "Free Models Router",
                isFree: true,
                supportsSpeedModes: true
            ),
            providerSupportsRouting: false
        )

        #expect(option.availableSpeedModes.isEmpty)
    }

    @Test("Reasoning menu uses catalog efforts")
    func reasoningMenuUsesCatalogEfforts() {
        let option = HomeModelOption(
            model: ChatModel(
                id: "openai/o4-mini",
                displayName: "O4 Mini",
                supportedReasoningEfforts: ["max", "high", "low"],
                reasoningMandatory: true
            )
        )

        #expect(option.availableReasoningEfforts.map(\.wireValue) == ["max", "high", "low"])
    }

    @Test("OpenCode requests use top-level reasoning_effort")
    func openCodeUsesTopLevelReasoningEffort() throws {
        let request = try ChatOpenAICompatibleStreamingClient.makeURLRequest(
            providerID: ProviderDescriptor.openCode.id,
            secret: "test-key",
            chatRequest: ChatRequest(
                conversationID: UUID(),
                messages: [.text(id: UUID(), role: .user, content: "Hi", timestamp: .init())],
                providerID: ProviderDescriptor.openCode.id,
                modelID: "glm-5",
                reasoningEffort: "high"
            )
        )

        let body = try JSONDecoder().decode(ReasoningProbe.self, from: request.httpBody ?? Data())
        #expect(body.reasoning == nil)
        #expect(body.reasoningEffort == "high")
    }

    @Test("Catalog entry resolves context length from alternate provider fields")
    func catalogContextLengthFromAlternateFields() throws {
        let contextField = try HomeModelCatalogClient.chatModel(
            fromCatalogEntryJSON: Data("""
            {"id":"gemma3","name":"Gemma 3","context":131072}
            """.utf8)
        )
        let maxModelLenField = try HomeModelCatalogClient.chatModel(
            fromCatalogEntryJSON: Data("""
            {"id":"vendor/model","name":"Model","max_model_len":200000}
            """.utf8)
        )

        #expect(contextField.contextLength == 131_072)
        #expect(maxModelLenField.contextLength == 200_000)
    }

    @Test("Catalog entry treats zero decimal pricing as free")
    func catalogZeroDecimalPricingIsFree() throws {
        let json = Data("""
        {"id":"vendor/model","name":"Free Model","pricing":{"prompt":"0.0","completion":"0.000"}}
        """.utf8)

        let model = try HomeModelCatalogClient.chatModel(fromCatalogEntryJSON: json)

        #expect(model.isFree)
    }

    @Test("Fast requests include provider routing payload")
    func fastRequestIncludesProviderRouting() throws {
        let request = try ChatOpenAICompatibleStreamingClient.makeURLRequest(
            providerID: ProviderDescriptor.openRouter.id,
            secret: "test-key",
            chatRequest: ChatRequest(
                conversationID: UUID(),
                messages: [.text(id: UUID(), role: .user, content: "Hi", timestamp: .init())],
                providerID: ProviderDescriptor.openRouter.id,
                modelID: "openrouter/free",
                providerSortBy: "throughput"
            )
        )

        let body = try JSONDecoder().decode(RequestProbe.self, from: request.httpBody ?? Data())
        #expect(body.provider?.sort.by == "throughput")
        #expect(body.provider?.sort.partition == "none")
    }

    @Test("Standard requests omit provider routing payload")
    func standardRequestOmitsProviderRouting() throws {
        let request = try ChatOpenAICompatibleStreamingClient.makeURLRequest(
            providerID: ProviderDescriptor.openRouter.id,
            secret: "test-key",
            chatRequest: ChatRequest(
                conversationID: UUID(),
                messages: [.text(id: UUID(), role: .user, content: "Hi", timestamp: .init())],
                providerID: ProviderDescriptor.openRouter.id,
                modelID: "openrouter/free"
            )
        )

        let body = try JSONDecoder().decode(RequestProbe.self, from: request.httpBody ?? Data())
        #expect(body.provider == nil)
    }

    @Test("Retry preserves provider throughput routing")
    func retryPreservesProviderSort() async {
        final class RequestLog: @unchecked Sendable {
            private let lock = NSLock()
            private var requests: [ChatRequest] = []

            func append(_ request: ChatRequest) {
                lock.lock()
                defer { lock.unlock() }
                requests.append(request)
            }

            func all() -> [ChatRequest] {
                lock.lock()
                defer { lock.unlock() }
                return requests
            }
        }

        let log = RequestLog()
        let preference = SidePanelInMemoryProviderPreferenceStore(
            preference: SidePanelProviderPreference(
                providerID: ProviderDescriptor.openRouter.id,
                modelID: "openrouter/free"
            )
        )
        let controller = ChatFlowController(
            streaming: ChatStreamingClient(stream: { request in
                log.append(request)
                return AsyncStream { continuation in
                    continuation.yield(.error("fail"))
                    continuation.finish()
                }
            }),
            providerPreference: preference
        )

        controller.setDraftMessage("Hello")
        await controller.sendMessage(providerSortBy: "throughput", reasoningEffort: "high")
        await controller.retry()

        let requests = log.all()
        #expect(requests.count == 2)
        #expect(requests[0].providerSortBy == "throughput")
        #expect(requests[1].providerSortBy == "throughput")
        #expect(requests[0].reasoningEffort == "high")
        #expect(requests[1].reasoningEffort == "high")
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

private nonisolated struct RequestProbe: Decodable {
    struct Reasoning: Decodable {
        let effort: String
    }

    let reasoning: Reasoning?
    let reasoningEffort: String?

    enum CodingKeys: String, CodingKey {
        case reasoning
        case reasoningEffort = "reasoning_effort"
        case provider
    }

    struct Provider: Decodable {
        struct Sort: Decodable {
            let by: String
            let partition: String
        }

        let sort: Sort
    }

    let provider: Provider?
}
