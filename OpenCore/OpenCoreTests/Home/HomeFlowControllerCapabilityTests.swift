import Foundation
import Testing

@testable import OpenCore

@MainActor
@Suite("Home Flow Controller Capabilities")
struct HomeFlowControllerCapabilityTests {
    private func waitForCapabilities(
        _ home: HomeFlowController,
        timeout: Duration = .seconds(2)
    ) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if home.state.inputCapabilities != nil, !home.state.isLoadingInputCapabilities {
                return true
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return home.state.inputCapabilities != nil && !home.state.isLoadingInputCapabilities
    }

    @Test("selectModel sets loading then resolves capabilities")
    func selectModelFetchesCapabilities() async {
        let home = HomeFlowController(
            catalog: HomeTestCatalog.client,
            capabilityClient: HomeModelCapabilityClient { _, _, _, fallback, _ in
                ModelInputCapabilities.from(fallback!)
            },
            credentialStore: HomeTestCatalog.credentialStoreWithKey(),
            providerPreference: InMemoryProviderPreferenceStore()
        )
        await home.onAppear()
        home.selectModel("meta-llama/llama-3.3-70b-instruct:free")
        #expect(await waitForCapabilities(home))
        #expect(home.state.isLoadingInputCapabilities == false)
        #expect(home.state.inputCapabilities != nil)
    }

    @Test("model switch clears stale capabilities while fetching")
    func clearsStaleCapabilitiesOnSwitch() async {
        let home = HomeFlowController(
            catalog: HomeTestCatalog.client,
            capabilityClient: HomeModelCapabilityClient { _, modelID, _, _, _ in
                if modelID.contains("deepseek") {
                    try? await Task.sleep(for: .milliseconds(200))
                    return ModelInputCapabilities(inputModalities: [.text])
                }
                return ModelInputCapabilities(inputModalities: [.text, .image])
            },
            credentialStore: HomeTestCatalog.credentialStoreWithKey(),
            providerPreference: InMemoryProviderPreferenceStore()
        )
        await home.onAppear()
        home.selectModel("meta-llama/llama-3.3-70b-instruct:free")
        #expect(await waitForCapabilities(home))
        #expect(home.state.inputCapabilities?.supportsImageInput == true)

        home.selectModel("deepseek/deepseek-r1:free")
        #expect(home.state.isLoadingInputCapabilities == true)
        #expect(home.state.inputCapabilities == nil)
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
            providerPreference: InMemoryProviderPreferenceStore()
        )
        home.onInputCapabilitiesResolved = { caps in
            if !caps.supportsAttachments { cleared = true }
        }
        await home.onAppear()
        #expect(await waitForCapabilities(home))
        #expect(cleared)
    }
}
