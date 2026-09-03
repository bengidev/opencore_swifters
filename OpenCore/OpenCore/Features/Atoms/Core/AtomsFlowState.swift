import Foundation

/// Snapshot of Atoms list data mutated through commands.
nonisolated struct AtomsFlowState: Equatable, Sendable {
    var entries: [AtomListEntry] = []
    var searchQuery: String = ""
    var activeAtomID: UUID?
    var availableGroups: [String] = []
    var expandedGroups: Set<String> = []

    var filteredEntries: [AtomListEntry] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = query.isEmpty
            ? entries
            : entries.filter {
                $0.lastMessagePreview.localizedCaseInsensitiveContains(query)
                    || $0.atom.title.localizedCaseInsensitiveContains(query)
            }
        return AtomsFlowState.deduplicatedPinnedFirst(base)
    }

    init(
        entries: [AtomListEntry] = [],
        searchQuery: String = "",
        activeAtomID: UUID? = nil,
        availableGroups: [String] = [],
        expandedGroups: Set<String> = []
    ) {
        self.entries = entries
        self.searchQuery = searchQuery
        self.activeAtomID = activeAtomID
        self.availableGroups = availableGroups
        self.expandedGroups = expandedGroups
    }

    static func sortedPinnedFirst(_ entries: [AtomListEntry]) -> [AtomListEntry] {
        entries.sorted { lhs, rhs in
            if lhs.atom.isPinned != rhs.atom.isPinned { return lhs.atom.isPinned }
            return lhs.lastMessageAt > rhs.lastMessageAt
        }
    }

    static func deduplicatedPinnedFirst(_ entries: [AtomListEntry]) -> [AtomListEntry] {
        let sorted = sortedPinnedFirst(entries)
        var seen = Set<UUID>()
        return sorted.filter { seen.insert($0.id).inserted }
    }
}
