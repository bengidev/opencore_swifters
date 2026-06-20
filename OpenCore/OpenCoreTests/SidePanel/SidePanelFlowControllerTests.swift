import Foundation
import Testing

@testable import OpenCore

@MainActor
@Suite("Side Panel Host Flow Controller")
struct SidePanelFlowControllerTests {
    /// Builds a host controller over in-memory test doubles so tests are
    /// hermetic and the backing stores can be asserted against directly.
    private func makeController(
        session: SidePanelSessionFlowController? = nil,
        credentialStore: SidePanelInMemoryCredentialStore = .init(),
        preferenceStore: SidePanelInMemoryProviderPreferenceStore = .init()
    ) -> SidePanelFlowController {
        let resolvedSession = session ?? SidePanelSessionFlowController()
        return SidePanelFlowController(
            session: resolvedSession,
            credentialStore: credentialStore,
            providerPreference: preferenceStore
        )
    }

    // MARK: - Settings presentation

    @Test("settingsButtonTapped presents setting controller with stored key status")
    func settingsButtonTappedPresentsWithStoredKey() async throws {
        let credentialStore = SidePanelInMemoryCredentialStore()
        try credentialStore.save("sk-test-key", for: SidePanelProviderAPI.default.id)

        let controller = makeController(credentialStore: credentialStore)
        controller.settingsButtonTapped()

        #expect(controller.setting != nil)
        #expect(controller.setting?.state.hasStoredKey == true)
    }

    @Test("settingsButtonTapped seeds reasoning model from preference")
    func settingsButtonTappedSeedsReasoningModel() {
        let preferenceStore = SidePanelInMemoryProviderPreferenceStore(
            preference: SidePanelProviderPreference(reasoningModel: .low)
        )

        let controller = makeController(preferenceStore: preferenceStore)
        controller.settingsButtonTapped()

        #expect(controller.setting?.state.reasoningModel == .low)
    }

    @Test("settingsButtonTapped seeds modelSupportsReasoning")
    func settingsButtonTappedSeedsModelSupportsReasoning() {
        let controller = makeController()
        controller.modelSupportsReasoning = true
        controller.settingsButtonTapped()

        #expect(controller.setting?.state.modelSupportsReasoning == true)
    }

    // MARK: - Session delegate forwarding

    @Test("session openConversation delegate forwards to host")
    func sessionOpenConversationForwardsToHost() {
        let session = SidePanelSessionFlowController()
        let controller = makeController(session: session)

        var openedConversation: SidePanelConversation?
        controller.onOpenConversation = { openedConversation = $0 }

        let convo = SidePanelConversation(
            id: UUID(),
            title: "Test Conversation",
            createdAt: Date(),
            updatedAt: Date(),
            isPinned: false,
            groupName: nil
        )
        session.selectConversation(convo)

        #expect(openedConversation?.id == convo.id)
        #expect(openedConversation?.title == "Test Conversation")
    }

    @Test("session activeConversationRenamed delegate forwards to host")
    func sessionActiveConversationRenamedForwardsToHost() {
        let conversationID = UUID()
        let session = SidePanelSessionFlowController(
            state: SidePanelSessionFlowState(activeConversationID: conversationID)
        )
        let controller = makeController(session: session)

        var renamedID: UUID?
        var renamedTitle: String?
        controller.onActiveConversationRenamed = { id, title in
            renamedID = id
            renamedTitle = title
        }

        session.dispatch(
            SidePanelSessionConversationRenamedCommand(id: conversationID, title: "Renamed")
        )

        #expect(renamedID == conversationID)
        #expect(renamedTitle == "Renamed")
    }

    @Test("session activeConversationDeleted delegate forwards to host")
    func sessionActiveConversationDeletedForwardsToHost() {
        let conversationID = UUID()
        let session = SidePanelSessionFlowController(
            state: SidePanelSessionFlowState(activeConversationID: conversationID)
        )
        let controller = makeController(session: session)

        var deletedID: UUID?
        controller.onActiveConversationDeleted = { deletedID = $0 }

        session.dispatch(
            SidePanelSessionConversationDeletedCommand(id: conversationID)
        )

        #expect(deletedID == conversationID)
    }

    // MARK: - Setting delegate forwarding

    @Test("setting credentialsChanged delegate forwards to host")
    func settingCredentialsChangedForwardsToHost() async throws {
        let credentialStore = SidePanelInMemoryCredentialStore()
        try credentialStore.save("sk-test-key", for: SidePanelProviderAPI.default.id)

        let controller = makeController(credentialStore: credentialStore)

        var credentialsChanged = false
        controller.onCredentialsChanged = { credentialsChanged = true }

        controller.settingsButtonTapped()
        controller.setting?.dispatch(SidePanelSettingDraftChangedCommand("sk-new"))
        controller.setting?.save()

        #expect(credentialsChanged)
    }

    @Test("setting providerChanged updates host selectedProviderID")
    func settingProviderChangedUpdatesHostProviderID() {
        let controller = makeController()

        var changedTo: String?
        controller.onProviderChanged = { changedTo = $0 }

        controller.settingsButtonTapped()
        controller.setting?.selectProvider("opencode")

        #expect(controller.selectedProviderID == "opencode")
        #expect(changedTo == "opencode")
    }

    @Test("dismissSettings fires credentialsChanged")
    func dismissSettingsFiresCredentialsChanged() {
        let controller = makeController()

        var credentialsChanged = false
        controller.onCredentialsChanged = { credentialsChanged = true }

        controller.dismissSettings()

        #expect(credentialsChanged)
        #expect(controller.setting == nil)
    }
}
