import Foundation
import Testing

@testable import OpenCore

@MainActor
@Suite("Settings Flow Controller")
struct SidePanelSettingFlowControllerTests {
    /// Builds a controller over in-memory test doubles so tests are hermetic
    /// and the backing stores can be asserted against directly.
    private func makeController(
        state: SidePanelSettingFlowState = SidePanelSettingFlowState(),
        credentialStore: CredentialInMemoryStore = CredentialInMemoryStore()
    ) -> SidePanelSettingFlowController {
        let preferenceStore = SidePanelInMemoryProviderPreferenceStore()
        return SidePanelSettingFlowController(
            state: state,
            credentialStore: credentialStore,
            providerPreference: preferenceStore
        )
    }

    // MARK: - onAppear

    @Test("onAppear reflects an already-stored key")
    func onAppearReflectsStoredKey() {
        let credentialStore = CredentialInMemoryStore()
        try! credentialStore.save("sk-existing", for: ProviderDescriptor.openRouter.id)

        let controller = makeController(credentialStore: credentialStore)
        controller.onAppear()

        #expect(controller.state.hasStoredKey == true)
    }

    // MARK: - save

    @Test("Saving a key persists it and flips hasStoredKey")
    func savePersistsKey() {
        let credentialStore = CredentialInMemoryStore()
        let controller = makeController(
            state: SidePanelSettingFlowState(draftAPIKey: "sk-new"),
            credentialStore: credentialStore
        )

        controller.save()

        #expect(controller.state.draftAPIKey == "")
        #expect(controller.state.hasStoredKey == true)
        #expect(credentialStore.secret(for: ProviderDescriptor.openRouter.id) == "sk-new")
    }

    @Test("Saving trims surrounding whitespace")
    func saveTrimsWhitespace() {
        let credentialStore = CredentialInMemoryStore()
        let controller = makeController(
            state: SidePanelSettingFlowState(draftAPIKey: "  sk-trim  "),
            credentialStore: credentialStore
        )

        controller.save()

        #expect(controller.state.draftAPIKey == "")
        #expect(controller.state.hasStoredKey == true)
        #expect(credentialStore.secret(for: ProviderDescriptor.openRouter.id) == "sk-trim")
    }

    @Test("Saving a blank draft is a no-op")
    func saveBlankIsNoOp() {
        let credentialStore = CredentialInMemoryStore()
        let controller = makeController(
            state: SidePanelSettingFlowState(draftAPIKey: "   "),
            credentialStore: credentialStore
        )

        controller.save()

        #expect(controller.state.hasStoredKey == false)
        #expect(credentialStore.secret(for: ProviderDescriptor.openRouter.id) == nil)
    }

    // MARK: - clear

    @Test("Clearing removes the stored key and resets state")
    func clearRemovesKey() {
        let credentialStore = CredentialInMemoryStore()
        try! credentialStore.save("sk-existing", for: ProviderDescriptor.openRouter.id)

        let controller = makeController(credentialStore: credentialStore)
        controller.onAppear()
        #expect(controller.state.hasStoredKey == true)

        controller.clear()

        #expect(controller.state.hasStoredKey == false)
        #expect(credentialStore.secret(for: ProviderDescriptor.openRouter.id) == nil)
    }

    // MARK: - canSave

    @Test("canSave is false for blank and true for non-blank drafts")
    func canSaveReflectsDraft() {
        var state = SidePanelSettingFlowState()
        #expect(state.canSave == false)
        state.draftAPIKey = "   "
        #expect(state.canSave == false)
        state.draftAPIKey = "sk-x"
        #expect(state.canSave == true)
    }
}
