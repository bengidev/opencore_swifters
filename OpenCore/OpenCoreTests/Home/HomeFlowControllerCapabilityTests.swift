import Foundation
import Testing

@testable import OpenCore

@MainActor
@Suite("Home Flow Controller Capabilities")
struct HomeFlowControllerCapabilityTests {
    @Test("selectModel sets loading then resolves capabilities")
    func selectModelFetchesCapabilities() async {
        let home = HomeFlowController(
            catalog: HomeTestCatalog.client,
            capabilityClient: HomeModelCapabilityClient { _, _, _, fallback, _ in
                ModelInputCapabilities.from(fallback!)
            },
            credentialStore: HomeTestCatalog.credentialStoreWithKey(),
            providerPreference: SidePanelInMemoryProviderPreferenceStore()
        )
        await home.onAppear()
        home.selectModel("meta-llama/llama-3.3-70b-instruct:free")
        try? await Task.sleep(for: .milliseconds(50))
        #expect(home.state.isLoadingInputCapabilities == false)
        #expect(home.state.inputCapabilities != nil)
    }

    @Test("resolved text-only capabilities invoke callback")
    func textOnlyCallback() async {
        var cleared = false
        let home = HomeFlowController(
            catalog: HomeTestCatalog.client,
            capabilityClient: HomeModelCapabilityClient { _, _, _, _, _ in
                ModelInputCapabilities(inputModalities: [.text])
            },
            credentialStore: HomeTestCatalog.credentialStoreWithKey(),
            providerPreference: SidePanelInMemoryProviderPreferenceStore()
        )
        home.onInputCapabilitiesResolved = { caps in
            if !caps.supportsAttachments { cleared = true }
        }
        await home.onAppear()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(cleared)
    }
}
