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

    func makeModelDetailURLRequest(modelID: String, secret: String) -> URLRequest? {
        guard let slash = modelID.firstIndex(of: "/") else { return nil }
        let author = String(modelID[..<slash])
        let slug = String(modelID[modelID.index(after: slash)...])
        var request = URLRequest(url: descriptor.modelDetailURL(author: author, slug: slug))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (field, value) in descriptor.defaultHeaders {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        return request
    }
}
