import Foundation
import Testing

@testable import OpenCore

@MainActor
@Suite("Settings Flow Controller")
struct SettingsFlowControllerTests {
    private func makeController(
        state: SettingsFlowState = SettingsFlowState(),
        credentialStore: CredentialInMemoryStore = CredentialInMemoryStore(),
        compactionStore: SettingsInMemoryContextCompactionPreferenceStore = SettingsInMemoryContextCompactionPreferenceStore()
    ) -> SettingsFlowController {
        SettingsFlowController(
            state: state,
            credentialStore: credentialStore,
            providerPreference: InMemoryProviderPreferenceStore(),
            contextCompactionPreference: compactionStore
        )
    }

    @Test("onAppear reflects an already-stored key")
    func onAppearReflectsStoredKey() {
        let credentialStore = CredentialInMemoryStore()
        try! credentialStore.save("sk-existing", for: ProviderDescriptor.openRouter.id)

        let controller = makeController(credentialStore: credentialStore)
        controller.onAppear()

        #expect(controller.state.hasStoredKey == true)
    }

    @Test("Saving a key persists it and flips hasStoredKey")
    func savePersistsKey() {
        let credentialStore = CredentialInMemoryStore()
        let controller = makeController(
            state: SettingsFlowState(draftAPIKey: "sk-new"),
            credentialStore: credentialStore
        )

        controller.save()

        #expect(controller.state.draftAPIKey == "")
        #expect(controller.state.hasStoredKey == true)
        #expect(credentialStore.secret(for: ProviderDescriptor.openRouter.id) == "sk-new")
    }

    @Test("Threshold percent change persists derived compaction settings")
    func thresholdPercentChangePersists() {
        let compactionStore = SettingsInMemoryContextCompactionPreferenceStore()
        let controller = makeController(compactionStore: compactionStore)
        controller.onAppear()

        controller.setContextCompactionThresholdPercent(80)

        let preference = compactionStore.preference()
        #expect(preference.triggerThresholdPercent == 80)
        #expect(controller.state.contextCompaction.triggerThresholdPercent == 80)
        #expect(preference.reserveTokens == SettingsContextCompactionPreference.derivedReserveTokens(for: 80))
        #expect(preference.keepRecentTokens == SettingsContextCompactionPreference.derivedKeepRecentTokens(for: 80))
    }
}
