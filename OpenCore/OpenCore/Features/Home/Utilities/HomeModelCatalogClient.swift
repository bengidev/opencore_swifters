import Foundation

private nonisolated let modelCatalogCacheTTL: TimeInterval = 60 * 60

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
        _ providerID: String,
        _ secret: String?,
        _ cachePreference: HomeModelCatalogCachePreferenceClient,
        _ urlSession: URLSession
    ) async -> CatalogResult

    static let live = HomeModelCatalogClient { providerID, secret, cachePreference, urlSession in
        guard let secret else {
            return CatalogResult(models: [])
        }

        let adapter = ProviderRegistry.resolve(id: providerID)
        let now = Date()
        if let cached = cachePreference.cachedCatalog(),
           cached.providerID == providerID,
           !cached.isStale(maxAge: modelCatalogCacheTTL, now: now),
           !cached.models.isEmpty {
            return CatalogResult(models: cached.models)
        }

        do {
            let models = try await Self.fetchModels(
                adapter: adapter,
                secret: secret,
                urlSession: urlSession
            )
            guard !models.isEmpty else {
                return Self.staleCachedModels(
                    for: providerID,
                    cachePreference: cachePreference
                ) ?? CatalogResult(models: [])
            }
            cachePreference.setCachedCatalog(
                ModelCatalogCachePreference(providerID: providerID, models: models, fetchedAt: now)
            )
            return CatalogResult(models: models)
        } catch let catalogError as CatalogFetchError {
            return Self.staleCachedModels(
                for: providerID,
                cachePreference: cachePreference,
                errorHint: catalogError.errorHint
            ) ?? CatalogResult(models: [], errorHint: catalogError.errorHint)
        } catch {
            return Self.staleCachedModels(for: providerID, cachePreference: cachePreference)
                ?? CatalogResult(models: [])
        }
    }

    static let preview = HomeModelCatalogClient { _, _, _, _ in
        CatalogResult(models: [])
    }

    private static func staleCachedModels(
        for providerID: String,
        cachePreference: HomeModelCatalogCachePreferenceClient,
        errorHint: String? = nil
    ) -> CatalogResult? {
        guard let cached = cachePreference.cachedCatalog(),
              cached.providerID == providerID,
              !cached.models.isEmpty else {
            return nil
        }
        return CatalogResult(models: cached.models, errorHint: errorHint)
    }

    private static func fetchModels(
        adapter: any ProviderAdapting,
        secret: String,
        urlSession: URLSession
    ) async throws -> [ChatModel] {
        let request = adapter.makeModelsListURLRequest(secret: secret)
        let (data, response) = try await urlSession.data(for: request)
        if let http = response as? HTTPURLResponse,
           !(200...299).contains(http.statusCode) {
            if http.statusCode == 403 {
                let providerMessage = ProviderOpenAICompatibleAdapter.decodeErrorBody(data)
                throw CatalogFetchError(
                    errorHint: providerMessage
                        ?? "Your plan doesn't include API access. Upgrade to use these endpoints."
                )
            }
            throw URLError(.badServerResponse)
        }

        return try ProviderCatalogParser.chatModels(fromCatalogJSON: data)
    }
}

extension HomeModelCatalogClient {
    nonisolated static func chatModel(fromCatalogEntryJSON data: Data) throws -> ChatModel {
        try ProviderCatalogParser.chatModel(fromCatalogEntryJSON: data)
    }
}
