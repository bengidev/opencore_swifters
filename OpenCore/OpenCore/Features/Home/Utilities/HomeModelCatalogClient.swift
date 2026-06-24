import Foundation

private nonisolated let modelCatalogCacheTTL: TimeInterval = 60 * 60

private nonisolated struct ProviderModelsResponse: Decodable, Sendable {
    let data: [ProviderModelEntry]
}

private nonisolated struct ProviderModelEntry: Decodable, Sendable {
    let id: String
    let name: String?
    let resolvedContextLength: Int?
    let architecture: Architecture?
    let pricing: Pricing?
    let supportedParameters: [String]?

    enum CodingKeys: String, CodingKey {
        case id, name
        case contextLength = "context_length"
        case context
        case maxModelLen = "max_model_len"
        case architecture
        case pricing
        case supportedParameters = "supported_parameters"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        let contextLength = try container.decodeIfPresent(Int.self, forKey: .contextLength)
        let context = try container.decodeIfPresent(Int.self, forKey: .context)
        let maxModelLen = try container.decodeIfPresent(Int.self, forKey: .maxModelLen)
        resolvedContextLength = contextLength ?? context ?? maxModelLen
        architecture = try container.decodeIfPresent(Architecture.self, forKey: .architecture)
        pricing = try container.decodeIfPresent(Pricing.self, forKey: .pricing)
        supportedParameters = try container.decodeIfPresent([String].self, forKey: .supportedParameters)
    }

    nonisolated struct Architecture: Decodable, Sendable {
        let modality: String?
        let tokenizer: String?
    }

    nonisolated struct Pricing: Decodable, Sendable {
        let prompt: String?
        let completion: String?
    }

    var isFree: Bool {
        if let pricing {
            return Self.isZeroPrice(pricing.prompt) && Self.isZeroPrice(pricing.completion)
        }
        if id.hasSuffix(":free") { return true }
        return false
    }

    var supportsReasoning: Bool {
        if let modality = architecture?.modality, modality.localizedCaseInsensitiveContains("reasoning") {
            return true
        }
        if supportedParameters?.contains(where: {
            $0.localizedCaseInsensitiveContains("reasoning")
        }) == true {
            return true
        }
        if id.localizedCaseInsensitiveContains(":thinking") { return true }
        return false
    }

    var supportsSpeedModes: Bool {
        architecture?.tokenizer == "Router"
    }

    func toChatModel() -> ChatModel {
        ChatModel(
            id: id,
            displayName: name ?? id,
            isFree: isFree,
            contextLength: resolvedContextLength,
            supportsReasoning: supportsReasoning,
            supportsSpeedModes: supportsSpeedModes
        )
    }

    private static func isZeroPrice(_ value: String?) -> Bool {
        guard let value else { return false }
        guard let decimal = Decimal(string: value) else { return value == "0" }
        return decimal == 0
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
            return CatalogResult(models: [])
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
                return Self.staleCachedModels(for: provider, cachePreference: cachePreference)
                    ?? CatalogResult(models: [])
            }
            cachePreference.setCachedCatalog(
                ModelCatalogCachePreference(providerID: provider.id, models: models, fetchedAt: now)
            )
            return CatalogResult(models: models)
        } catch let catalogError as CatalogFetchError {
            return Self.staleCachedModels(
                for: provider,
                cachePreference: cachePreference,
                errorHint: catalogError.errorHint
            ) ?? CatalogResult(models: [], errorHint: catalogError.errorHint)
        } catch {
            return Self.staleCachedModels(for: provider, cachePreference: cachePreference)
                ?? CatalogResult(models: [])
        }
    }

    static let preview = HomeModelCatalogClient { _, _, _, _ in
        CatalogResult(models: [])
    }

    private static func staleCachedModels(
        for provider: SidePanelProviderAPI,
        cachePreference: HomeModelCatalogCachePreferenceClient,
        errorHint: String? = nil
    ) -> CatalogResult? {
        guard let cached = cachePreference.cachedCatalog(),
              cached.providerID == provider.id,
              !cached.models.isEmpty else {
            return nil
        }
        return CatalogResult(models: cached.models, errorHint: errorHint)
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

extension HomeModelCatalogClient {
    nonisolated static func chatModel(fromCatalogEntryJSON data: Data) throws -> ChatModel {
        let entry = try JSONDecoder().decode(ProviderModelEntry.self, from: data)
        return entry.toChatModel()
    }
}
