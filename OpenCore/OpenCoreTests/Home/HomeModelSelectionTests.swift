import Foundation
import Testing

@testable import OpenCore

@MainActor
@Suite("Home Model Selection")
struct HomeModelSelectionTests {
    @Test("Catalog load auto-selects first model when none stored")
    func autoSelectsDefaultModel() async {
        let preference = SidePanelInMemoryProviderPreferenceStore()
        let credentialStore = SidePanelInMemoryCredentialStore()
        try? credentialStore.save("test-key", for: SidePanelProviderAPI.default.id)
        let home = HomeFlowController(
            catalog: .preview,
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
            credentialStore: SidePanelInMemoryCredentialStore(),
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
                providerID: SidePanelProviderAPI.openRouter.id,
                modelID: "meta-llama/llama-3.3-70b-instruct:free"
            )
        )
        let home = HomeFlowController(
            catalog: .preview,
            credentialStore: SidePanelInMemoryCredentialStore(),
            providerPreference: preference
        )
        await home.onAppear()
        #expect(home.state.selectedModelID != nil)

        await home.handleProviderChanged(SidePanelProviderAPI.commandCode.id)

        #expect(preference.preference().modelID != "meta-llama/llama-3.3-70b-instruct:free")
        #expect(home.state.selectedProviderID == SidePanelProviderAPI.commandCode.id)
    }
}
