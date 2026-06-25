import Foundation
import Testing

@testable import OpenCore

@MainActor
@Suite("Home Model Selection")
struct HomeModelSelectionTests {
    @Test("Catalog load auto-selects first model when none stored")
    func autoSelectsDefaultModel() async {
        let preference = SidePanelInMemoryProviderPreferenceStore()
        let credentialStore = CredentialInMemoryStore()
        try? credentialStore.save("test-key", for: ProviderDescriptor.openRouter.id)
        let home = HomeFlowController(
            catalog: HomeTestCatalog.client,
            credentialStore: credentialStore,
            providerPreference: preference
        )

        await home.onAppear()

        #expect(home.state.hasSelectedModel)
        #expect(preference.preference().modelID != nil)
    }

    @Test("Selecting a model persists to preference store")
    func selectModelPersists() {
        let preference = SidePanelInMemoryProviderPreferenceStore()
        let home = HomeFlowController(
            credentialStore: CredentialInMemoryStore(),
            providerPreference: preference
        )

        home.selectModel("deepseek/deepseek-r1:free")

        #expect(home.state.selectedModelID == "deepseek/deepseek-r1:free")
        #expect(preference.preference().modelID == "deepseek/deepseek-r1:free")
    }

    @Test("Provider change clears model and reloads catalog")
    func providerChangeClearsModel() async {
        let preference = SidePanelInMemoryProviderPreferenceStore(
            preference: SidePanelProviderPreference(
                providerID: ProviderDescriptor.openRouter.id,
                modelID: "meta-llama/llama-3.3-70b-instruct:free"
            )
        )
        let credentialStore = CredentialInMemoryStore()
        try? credentialStore.save("test-key", for: ProviderDescriptor.openRouter.id)
        try? credentialStore.save("test-key", for: ProviderDescriptor.commandCode.id)
        let home = HomeFlowController(
            catalog: HomeTestCatalog.client,
            credentialStore: credentialStore,
            providerPreference: preference
        )
        await home.onAppear()
        #expect(home.state.selectedModelID != nil)

        await home.handleProviderChanged(ProviderDescriptor.commandCode.id)

        #expect(preference.preference().modelID != "meta-llama/llama-3.3-70b-instruct:free")
        #expect(home.state.selectedProviderID == ProviderDescriptor.commandCode.id)
    }

    @Test("Empty catalog without API key disables model selection")
    func emptyCatalogWithoutKey() async {
        let home = HomeFlowController(
            catalog: HomeTestCatalog.client,
            credentialStore: CredentialInMemoryStore(),
            providerPreference: SidePanelInMemoryProviderPreferenceStore()
        )

        await home.onAppear()

        #expect(!home.state.isModelCatalogAvailable)
        #expect(!home.state.hasSelectedModel)
        #expect(home.state.modelPickerTitle == "Not Available")
    }

    @Test("Stale persisted model auto-replaces with first catalog model")
    func stalePersistedModelAutoReplaced() async {
        let preference = SidePanelInMemoryProviderPreferenceStore(
            preference: SidePanelProviderPreference(modelID: "removed-model-id")
        )
        let home = HomeFlowController(
            catalog: HomeTestCatalog.client,
            credentialStore: HomeTestCatalog.credentialStoreWithKey(),
            providerPreference: preference
        )

        await home.onAppear()

        #expect(home.state.hasSelectedModel)
        #expect(preference.preference().modelID == HomeTestCatalog.sampleModels[0].id)
    }

    @Test("Catalog fetch error is stored when models unavailable")
    func catalogErrorStored() async {
        let catalog = HomeModelCatalogClient { _, secret, _, _ in
            guard secret != nil else { return HomeModelCatalogClient.CatalogResult(models: []) }
            return HomeModelCatalogClient.CatalogResult(
                models: [],
                errorHint: "Plan upgrade required"
            )
        }
        let home = HomeFlowController(
            catalog: catalog,
            credentialStore: HomeTestCatalog.credentialStoreWithKey(),
            providerPreference: SidePanelInMemoryProviderPreferenceStore()
        )

        await home.onAppear()

        #expect(home.state.catalogError == "Plan upgrade required")
        #expect(!home.state.isModelCatalogAvailable)
    }
}
