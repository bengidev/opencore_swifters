import Foundation

/// OpenRouter-specific adapter: nested reasoning object and provider routing.
nonisolated struct ProviderOpenRouterAdapter: ProviderAdapting {
    private let base: ProviderOpenAICompatibleAdapter

    init() {
        base = ProviderOpenAICompatibleAdapter(
            descriptor: .openRouter,
            reasoningWireStyle: .reasoningObject,
            supportsProviderRouting: true
        )
    }

    var descriptor: ProviderDescriptor { base.descriptor }
    var supportsProviderRouting: Bool { base.supportsProviderRouting }

    func makeChatCompletionURLRequest(secret: String, chatRequest: ChatRequest) throws -> URLRequest {
        try base.makeChatCompletionURLRequest(secret: secret, chatRequest: chatRequest)
    }

    func makeModelsListURLRequest(secret: String) -> URLRequest {
        base.makeModelsListURLRequest(secret: secret)
    }
}
