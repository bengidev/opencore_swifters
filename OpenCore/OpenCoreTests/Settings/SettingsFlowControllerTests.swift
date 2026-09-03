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

    @Test("Reserve token change persists to compaction store")
    func reserveTokenChangePersists() {
        let compactionStore = SettingsInMemoryContextCompactionPreferenceStore()
        let controller = makeController(compactionStore: compactionStore)
        controller.onAppear()

        controller.setContextCompactionReserveTokens(20_480)

        #expect(compactionStore.preference().reserveTokens == 20_480)
        #expect(controller.state.contextCompaction.reserveTokens == 20_480)
    }

    @Test("Keep recent token change persists to compaction store")
    func keepRecentTokenChangePersists() {
        let compactionStore = SettingsInMemoryContextCompactionPreferenceStore()
        let controller = makeController(compactionStore: compactionStore)
        controller.onAppear()

        controller.setContextCompactionKeepRecentTokens(24_576)

        #expect(compactionStore.preference().keepRecentTokens == 24_576)
        #expect(controller.state.contextCompaction.keepRecentTokens == 24_576)
    }
}
