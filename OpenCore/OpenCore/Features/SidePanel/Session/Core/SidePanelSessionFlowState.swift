import Foundation

/// Snapshot of side panel session data mutated through commands.
nonisolated struct SidePanelSessionFlowState: Equatable, Sendable {
    var isSidebarVisible = false
    var conversations: [SidePanelConversation] = []
    var historySearchQuery: String = ""
    var activeConversationID: UUID?
    var availableGroups: [String] = []
    var expandedGroups: Set<String> = []

    /// Conversations after applying the search filter and deduplicating by id.
    /// Pinned-first ordering from the client is preserved.
    var filteredConversations: [SidePanelConversation] {
        let query = historySearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = query.isEmpty
            ? conversations
            : conversations.filter { $0.title.localizedCaseInsensitiveContains(query) }
        return SidePanelSessionFlowState.deduplicatedPinnedFirst(base)
    }

    init(
        isSidebarVisible: Bool = false,
        conversations: [SidePanelConversation] = [],
        historySearchQuery: String = "",
        activeConversationID: UUID? = nil,
        availableGroups: [String] = [],
        expandedGroups: Set<String> = []
    ) {
        self.isSidebarVisible = isSidebarVisible
        self.conversations = conversations
        self.historySearchQuery = historySearchQuery
        self.activeConversationID = activeConversationID
        self.availableGroups = availableGroups
        self.expandedGroups = expandedGroups
    }

    // MARK: - Sort helpers

    static func sortedPinnedFirst(_ conversations: [SidePanelConversation]) -> [SidePanelConversation] {
        conversations.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    /// Pinned-first sort then keep one row per id (pinned copy wins).
    static func deduplicatedPinnedFirst(_ conversations: [SidePanelConversation]) -> [SidePanelConversation] {
        let sorted = sortedPinnedFirst(conversations)
        var seen = Set<UUID>()
        return sorted.filter { seen.insert($0.id).inserted }
    }
}
