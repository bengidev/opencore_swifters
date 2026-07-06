import Foundation

nonisolated struct HomeModelCapabilityClient: Sendable {
    var fetchCapabilities: @Sendable (
        _ providerID: String,
        _ modelID: String,
        _ secret: String?,
        _ catalogFallback: ChatModel?,
        _ urlSession: URLSession
    ) async -> ModelInputCapabilities

    static let live = HomeModelCapabilityClient { providerID, modelID, secret, catalogFallback, urlSession in
        guard let secret else {
            return ModelInputCapabilities(inputModalities: [.text])
        }
        let adapter = ProviderRegistry.resolve(id: providerID)
        if let request = adapter.makeModelDetailURLRequest(modelID: modelID, secret: secret) {
            do {
                let (data, response) = try await urlSession.data(for: request)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    if let caps = try? parseCapabilities(from: data) {
                        return caps
                    }
                }
            } catch {}
        }
        if let catalogFallback {
            return ModelInputCapabilities.from(catalogFallback)
        }
        return ModelInputCapabilities(inputModalities: [.text])
    }

    static let preview = HomeModelCapabilityClient { _, _, _, catalogFallback, _ in
        catalogFallback.map(ModelInputCapabilities.from)
            ?? ModelInputCapabilities(inputModalities: [.text])
    }
}

private nonisolated func parseCapabilities(from data: Data) throws -> ModelInputCapabilities {
    if let caps = try? ProviderCatalogParser.modelInputCapabilities(fromCatalogEntryJSON: data) {
        return caps
    }
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let dataObject = json["data"],
          JSONSerialization.isValidJSONObject(dataObject) else {
        throw URLError(.cannotParseResponse)
    }
    let nested = try JSONSerialization.data(withJSONObject: dataObject)
    return try ProviderCatalogParser.modelInputCapabilities(fromCatalogEntryJSON: nested)
}
