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
            providerPreference: SidePanelInMemoryProviderPreferenceStore(),
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

    @Test("Threshold change persists to compaction store when auto is off")
    func thresholdChangePersistsWhenAutoOff() {
        let compactionStore = SettingsInMemoryContextCompactionPreferenceStore()
        let controller = makeController(compactionStore: compactionStore)
        controller.onAppear()
        controller.setContextCompactionEnabled(false)

        controller.setContextCompactionThresholdPercent(80)

        #expect(compactionStore.preference().triggerThresholdPercent == 80)
        #expect(controller.state.contextCompaction.triggerThresholdPercent == 80)
    }

    @Test("Threshold change is ignored while automatic compaction is on")
    func thresholdChangeIgnoredWhenAutoOn() {
        let compactionStore = SettingsInMemoryContextCompactionPreferenceStore()
        var preference = compactionStore.preference()
        preference.isEnabled = true
        preference.triggerThresholdPercent = 90
        compactionStore.setPreference(preference)

        let controller = makeController(compactionStore: compactionStore)
        controller.onAppear()
        controller.setContextCompactionThresholdPercent(75)

        #expect(compactionStore.preference().triggerThresholdPercent == 90)
        #expect(controller.state.contextCompaction.triggerThresholdPercent == 90)
    }
}
