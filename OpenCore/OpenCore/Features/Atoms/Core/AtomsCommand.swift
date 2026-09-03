import Foundation

protocol AtomsCommand: Sendable {
    func execute(on state: inout AtomsFlowState)
}

struct AtomsSearchQueryChangedCommand: AtomsCommand {
    let query: String

    func execute(on state: inout AtomsFlowState) {
        state.searchQuery = query
    }
}

struct AtomsPinToggledCommand: AtomsCommand {
    let atomID: UUID

    func execute(on state: inout AtomsFlowState) {
        let matching = state.entries.indices.filter { state.entries[$0].atom.id == atomID }
        guard let first = matching.first else { return }
        let newValue = !state.entries[first].atom.isPinned
        for idx in matching {
            state.entries[idx].atom.isPinned = newValue
        }
        state.entries = AtomsFlowState.deduplicatedPinnedFirst(state.entries)
    }
}

struct AtomsRenamedCommand: AtomsCommand {
    let id: UUID
    let title: String

    func execute(on state: inout AtomsFlowState) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let matching = state.entries.indices.filter { state.entries[$0].atom.id == id }
        guard !matching.isEmpty else { return }
        let now = Date()
        for idx in matching {
            state.entries[idx].atom.title = trimmed
            state.entries[idx].atom.updatedAt = now
        }
        state.entries = AtomsFlowState.sortedPinnedFirst(state.entries)
    }
}

struct AtomsDeletedCommand: AtomsCommand {
    let id: UUID

    func execute(on state: inout AtomsFlowState) {
        state.entries.removeAll { $0.atom.id == id }
    }
}

struct AtomsGroupChangedCommand: AtomsCommand {
    let id: UUID
    let group: String?

    func execute(on state: inout AtomsFlowState) {
        let normalizedGroup: String? = {
            guard let group else { return nil }
            let trimmed = group.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }()
        if let normalizedGroup {
            state.expandedGroups.insert(normalizedGroup)
        }
        let matching = state.entries.indices.filter { state.entries[$0].atom.id == id }
        guard !matching.isEmpty else { return }
        for idx in matching {
            state.entries[idx].atom.groupName = normalizedGroup
        }
        state.entries = AtomsFlowState.sortedPinnedFirst(state.entries)
    }
}

struct AtomsGroupHeaderToggledCommand: AtomsCommand {
    let group: String

    func execute(on state: inout AtomsFlowState) {
        if state.expandedGroups.contains(group) {
            state.expandedGroups.remove(group)
        } else {
            state.expandedGroups.insert(group)
        }
    }
}

struct AtomsCommandInvoker: Sendable {
    func invoke(_ command: any AtomsCommand, on state: inout AtomsFlowState) {
        command.execute(on: &state)
    }
}
