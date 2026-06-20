import Foundation

/// Encapsulates a single side panel session mutation.
protocol SidePanelSessionCommand: Sendable {
    func execute(on state: inout SidePanelSessionFlowState)
}

// MARK: - Sidebar visibility

struct SidePanelSessionSidebarToggleCommand: SidePanelSessionCommand {
    func execute(on state: inout SidePanelSessionFlowState) {
        state.isSidebarVisible.toggle()
    }
}

struct SidePanelSessionSidebarDismissCommand: SidePanelSessionCommand {
    func execute(on state: inout SidePanelSessionFlowState) {
        state.isSidebarVisible = false
    }
}

// MARK: - Search

struct SidePanelSessionHistorySearchQueryChangedCommand: SidePanelSessionCommand {
    let query: String

    func execute(on state: inout SidePanelSessionFlowState) {
        state.historySearchQuery = query
    }
}

// MARK: - Pin

struct SidePanelSessionConversationPinToggledCommand: SidePanelSessionCommand {
    let conversation: SidePanelConversation

    func execute(on state: inout SidePanelSessionFlowState) {
        let matching = state.conversations.indices.filter {
            state.conversations[$0].id == conversation.id
        }
        guard let first = matching.first else { return }
        let newValue = !state.conversations[first].isPinned
        for idx in matching {
            state.conversations[idx].isPinned = newValue
        }
        state.conversations = SidePanelSessionFlowState.deduplicatedPinnedFirst(state.conversations)
    }
}

// MARK: - Rename

struct SidePanelSessionConversationRenamedCommand: SidePanelSessionCommand {
    let id: UUID
    let title: String

    func execute(on state: inout SidePanelSessionFlowState) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let matching = state.conversations.indices.filter {
            state.conversations[$0].id == id
        }
        guard !matching.isEmpty else { return }
        let now = Date()
        for idx in matching {
            state.conversations[idx].title = trimmed
            state.conversations[idx].updatedAt = now
        }
        state.conversations = SidePanelSessionFlowState.sortedPinnedFirst(state.conversations)
    }
}

// MARK: - Delete

struct SidePanelSessionConversationDeletedCommand: SidePanelSessionCommand {
    let id: UUID

    func execute(on state: inout SidePanelSessionFlowState) {
        state.conversations.removeAll { $0.id == id }
    }
}

// MARK: - Group change

struct SidePanelSessionConversationGroupChangedCommand: SidePanelSessionCommand {
    let id: UUID
    let group: String?

    func execute(on state: inout SidePanelSessionFlowState) {
        let normalizedGroup: String? = {
            guard let group else { return nil }
            let trimmed = group.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }()
        if let normalizedGroup {
            state.expandedGroups.insert(normalizedGroup)
        }
        let matching = state.conversations.indices.filter {
            state.conversations[$0].id == id
        }
        guard !matching.isEmpty else { return }
        for idx in matching {
            state.conversations[idx].groupName = normalizedGroup
        }
        state.conversations = SidePanelSessionFlowState.sortedPinnedFirst(state.conversations)
    }
}

// MARK: - Group header toggle

struct SidePanelSessionGroupHeaderToggledCommand: SidePanelSessionCommand {
    let group: String

    func execute(on state: inout SidePanelSessionFlowState) {
        if state.expandedGroups.contains(group) {
            state.expandedGroups.remove(group)
        } else {
            state.expandedGroups.insert(group)
        }
    }
}

// MARK: - Invoker

/// Dispatches side panel session commands without exposing mutation rules to callers.
struct SidePanelSessionCommandInvoker: Sendable {
    func invoke(_ command: any SidePanelSessionCommand, on state: inout SidePanelSessionFlowState) {
        command.execute(on: &state)
    }
}
