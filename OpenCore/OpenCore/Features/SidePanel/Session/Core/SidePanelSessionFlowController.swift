import Foundation
import Observation

/// Single entry point for side panel session scope — loads conversations,
/// drives sidebar visibility, persists pin/rename/delete/group edits,
/// and surfaces delegate callbacks for the parent to drive live chat.
@MainActor
@Observable
final class SidePanelSessionFlowController {
    private(set) var state: SidePanelSessionFlowState
    private let history: SidePanelHistoryClient
    private let invoker = SidePanelSessionCommandInvoker()

    /// The user picked a conversation to open in chat.
    var onOpenConversation: ((SidePanelConversation) -> Void)?
    /// The on-screen conversation was renamed.
    var onActiveConversationRenamed: ((UUID, String) -> Void)?
    /// The on-screen conversation was deleted and should be cleared.
    var onActiveConversationDeleted: ((UUID) -> Void)?
    /// The user tapped the settings gear. The session scope does not present
    /// settings itself; the host owns the settings sheet, so this fires the
    /// delegate and the host presents.
    var onSettingsTapped: (() -> Void)?

    init(
        state: SidePanelSessionFlowState = SidePanelSessionFlowState(),
        history: SidePanelHistoryClient = .preview
    ) {
        self.state = state
        self.history = history
    }

    // MARK: - Dispatch

    func dispatch(_ command: any SidePanelSessionCommand) {
        let priorActiveID = state.activeConversationID
        invoker.invoke(command, on: &state)

        // Fire rename delegate if active conversation was renamed.
        if let cmd = command as? SidePanelSessionConversationRenamedCommand {
            let trimmed = cmd.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, cmd.id == priorActiveID {
                onActiveConversationRenamed?(cmd.id, trimmed)
            }
        }

        // Fire delete delegate if active conversation was deleted.
        if let cmd = command as? SidePanelSessionConversationDeletedCommand,
           cmd.id == priorActiveID {
            onActiveConversationDeleted?(cmd.id)
        }
    }

    // MARK: - Sidebar toggle

    func toggleSidebar() async {
        dispatch(SidePanelSessionSidebarToggleCommand())

        guard state.isSidebarVisible else { return }

        // Load conversations + groups when opening.
        if let conversations = try? await history.listConversations() {
            state.conversations = SidePanelSessionFlowState.deduplicatedPinnedFirst(conversations)
        }
        if let groups = try? await history.listGroups() {
            state.availableGroups = groups
        }
    }

    // MARK: - Select conversation

    func selectConversation(_ conversation: SidePanelConversation) {
        state.isSidebarVisible = false
        onOpenConversation?(conversation)
    }

    // MARK: - Settings (host presents via onSettingsTapped)

    func settingsButtonTapped() {
        onSettingsTapped?()
    }

    // MARK: - Pin persistence

    func pinConversation(_ conversation: SidePanelConversation) async {
        let currentValue = state.conversations.first(where: { $0.id == conversation.id })?.isPinned ?? false
        let newValue = !currentValue
        dispatch(SidePanelSessionConversationPinToggledCommand(conversation: conversation))
        try? await history.setPinned(conversation.id, newValue)
    }

    // MARK: - Rename persistence

    func renameConversation(id: UUID, title: String) async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        dispatch(SidePanelSessionConversationRenamedCommand(id: id, title: title))
        try? await history.renameConversation(id, trimmed)
    }

    // MARK: - Delete persistence

    func deleteConversation(id: UUID) async {
        dispatch(SidePanelSessionConversationDeletedCommand(id: id))
        try? await history.deleteConversation(id)
        if let groups = try? await history.listGroups() {
            state.availableGroups = groups
        }
    }

    // MARK: - Group change persistence

    func changeGroup(id: UUID, group: String?) async {
        dispatch(SidePanelSessionConversationGroupChangedCommand(id: id, group: group))
        try? await history.setGroup(id, group)
        if let groups = try? await history.listGroups() {
            state.availableGroups = groups
        }
    }
}
