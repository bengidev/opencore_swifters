import Foundation

@testable import OpenCore

enum HomeTestCatalog {
    nonisolated static let sampleModels: [ChatModel] = [
        ChatModel(
            id: "meta-llama/llama-3.3-70b-instruct:free",
            displayName: "Llama 3.3 70B",
            isFree: true,
            contextLength: 131_072
        ),
        ChatModel(
            id: "deepseek/deepseek-r1:free",
            displayName: "DeepSeek R1",
            isFree: true,
            contextLength: 163_840,
            supportedReasoningEfforts: ["low", "medium", "high"]
        )
    ]

    nonisolated static func credentialStoreWithKey(
        for providerID: String = ProviderDescriptor.openRouter.id
    ) -> CredentialInMemoryStore {
        let store = CredentialInMemoryStore()
        try? store.save("test-key", for: providerID)
        return store
    }

    nonisolated static let client = HomeModelCatalogClient { providerID, secret, _, _ in
        guard secret != nil else {
            return HomeModelCatalogClient.CatalogResult(models: [])
        }
        switch providerID {
        case ProviderDescriptor.commandCode.id:
            return HomeModelCatalogClient.CatalogResult(models: [
                ChatModel(id: "claude-sonnet-4-6", displayName: "Claude Sonnet 4.6", contextLength: 200_000)
            ])
        default:
            return HomeModelCatalogClient.CatalogResult(models: sampleModels)
        }
    }
}
