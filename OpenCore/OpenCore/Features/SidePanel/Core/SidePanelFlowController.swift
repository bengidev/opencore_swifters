import Foundation
import Observation

/// Host flow controller for the side panel session browser.
@MainActor
@Observable
final class SidePanelFlowController {
    let session: SidePanelSessionFlowController

    private(set) var selectedProviderID: String

    var isSidebarVisible: Bool { session.state.isSidebarVisible }

    var onOpenConversation: ((SidePanelConversation) -> Void)?
    var onActiveConversationRenamed: ((UUID, String) -> Void)?
    var onActiveConversationDeleted: ((UUID) -> Void)?

    init(session: SidePanelSessionFlowController = .init()) {
        self.session = session
        self.selectedProviderID = ProviderDescriptor.openRouter.id

        session.onOpenConversation = { [weak self] convo in
            self?.onOpenConversation?(convo)
        }
        session.onActiveConversationRenamed = { [weak self] id, title in
            self?.onActiveConversationRenamed?(id, title)
        }
        session.onActiveConversationDeleted = { [weak self] id in
            self?.onActiveConversationDeleted?(id)
        }
    }

    func syncSelectedProviderID(_ id: String) {
        selectedProviderID = id
    }
}
