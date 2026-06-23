import Foundation

private nonisolated let modelCatalogCacheTTL: TimeInterval = 60 * 60

private nonisolated struct ProviderModelsResponse: Decodable, Sendable {
    let data: [ProviderModelEntry]
}

private nonisolated struct ProviderModelEntry: Decodable, Sendable {
    let id: String
    let name: String?
    let contextLength: Int?
    let architecture: Architecture?
    let pricing: Pricing?

    enum CodingKeys: String, CodingKey {
        case id, name
        case contextLength = "context_length"
        case architecture
        case pricing
    }

    nonisolated struct Architecture: Decodable, Sendable {
        let modality: String?
    }

    nonisolated struct Pricing: Decodable, Sendable {
        let prompt: String?
        let completion: String?
    }

    var isFree: Bool {
        if let pricing {
            return pricing.prompt == "0" && pricing.completion == "0"
        }
        if let name { return name.lowercased().contains("free") }
        return false
    }

    var supportsReasoning: Bool {
        let reasoningIDs: Set<String> = [
            "deepseek-r1", "deepseek-r1-distill",
            "deepseek/deepseek-r1", "deepseek/deepseek-r1-distill",
            "openai/o1", "openai/o3", "openai/o1-mini", "openai/o3-mini",
            "qwen/qwq", "qwen/qvq",
            "deepseek-v4-pro", "deepseek-v4-flash",
            "kimi-k2.5", "kimi-k2.6"
        ]
        for prefix in reasoningIDs where id.hasPrefix(prefix) || id.contains(prefix) {
            return true
        }
        if let modality = architecture?.modality, modality.contains("reasoning") { return true }
        return false
    }

    func toChatModel() -> ChatModel {
        ChatModel(
            id: id,
            displayName: name ?? id,
            isFree: isFree,
            contextLength: contextLength,
            supportsReasoning: supportsReasoning
        )
    }
}

nonisolated struct HomeModelCatalogClient: Sendable {
    struct CatalogResult: Equatable, Sendable {
        let models: [ChatModel]
        let errorHint: String?

        init(models: [ChatModel], errorHint: String? = nil) {
            self.models = models
            self.errorHint = errorHint
        }
    }

    struct CatalogFetchError: Error, Sendable {
        let errorHint: String
    }

    var listModels: @Sendable (
        _ provider: SidePanelProviderAPI,
        _ secret: String?,
        _ cachePreference: HomeModelCatalogCachePreferenceClient,
        _ urlSession: URLSession
    ) async -> CatalogResult

    static let live = HomeModelCatalogClient { provider, secret, cachePreference, urlSession in
        guard let secret else {
            return CatalogResult(models: ChatModel.curatedFallback(for: provider.id))
        }

        let now = Date()
        if let cached = cachePreference.cachedCatalog(),
           cached.providerID == provider.id,
           !cached.isStale(maxAge: modelCatalogCacheTTL, now: now),
           !cached.models.isEmpty {
            return CatalogResult(models: cached.models)
        }

        do {
            let models = try await Self.fetchModels(from: provider, secret: secret, urlSession: urlSession)
            guard !models.isEmpty else {
                return CatalogResult(models: ChatModel.curatedFallback(for: provider.id))
            }
            cachePreference.setCachedCatalog(
                ModelCatalogCachePreference(providerID: provider.id, models: models, fetchedAt: now)
            )
            return CatalogResult(models: models)
        } catch let catalogError as CatalogFetchError {
            if let cached = cachePreference.cachedCatalog(),
               cached.providerID == provider.id,
               !cached.models.isEmpty {
                return CatalogResult(models: cached.models, errorHint: catalogError.errorHint)
            }
            return CatalogResult(
                models: ChatModel.curatedFallback(for: provider.id),
                errorHint: catalogError.errorHint
            )
        } catch {
            if let cached = cachePreference.cachedCatalog(),
               cached.providerID == provider.id,
               !cached.models.isEmpty {
                return CatalogResult(models: cached.models)
            }
            return CatalogResult(models: ChatModel.curatedFallback(for: provider.id))
        }
    }

    static let preview = HomeModelCatalogClient { provider, _, _, _ in
        CatalogResult(models: ChatModel.curatedFallback(for: provider.id))
    }

    private static func fetchModels(
        from provider: SidePanelProviderAPI,
        secret: String,
        urlSession: URLSession
    ) async throws -> [ChatModel] {
        var request = URLRequest(url: provider.modelsURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (field, value) in provider.defaultHeaders {
            request.setValue(value, forHTTPHeaderField: field)
        }
        switch provider.authScheme {
        case .bearer:
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await urlSession.data(for: request)
        if let http = response as? HTTPURLResponse,
           !(200...299).contains(http.statusCode) {
            if http.statusCode == 403 {
                let providerMessage = ChatOpenAICompatibleStreamingClient.decodeErrorBody(data)
                throw CatalogFetchError(
                    errorHint: providerMessage
                        ?? "Your plan doesn't include API access. Upgrade to use these endpoints."
                )
            }
            throw URLError(.badServerResponse)
        }

        let envelope = try JSONDecoder().decode(ProviderModelsResponse.self, from: data)
        return envelope.data
            .filter { entry in
                let modality = entry.architecture?.modality ?? ""
                return modality.isEmpty || modality.contains("text")
            }
            .map { $0.toChatModel() }
            .sorted { lhs, rhs in
                if lhs.isFree != rhs.isFree { return lhs.isFree }
                return lhs.displayName.localizedCompare(rhs.displayName) == .orderedAscending
            }
    }
}
