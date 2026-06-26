import Foundation
import Testing

@testable import OpenCore

@MainActor
@Suite("Side Panel Host Flow Controller")
struct SidePanelFlowControllerTests {
    private func makeController(
        session: SidePanelSessionFlowController? = nil
    ) -> SidePanelFlowController {
        SidePanelFlowController(session: session ?? SidePanelSessionFlowController())
    }

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

    @Test("syncSelectedProviderID updates mirrored provider id")
    func syncSelectedProviderIDUpdatesMirror() {
        let controller = makeController()
        controller.syncSelectedProviderID("opencode")
        #expect(controller.selectedProviderID == "opencode")
    }
}
