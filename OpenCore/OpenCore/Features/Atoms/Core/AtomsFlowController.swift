import Foundation
import Observation

/// Flow controller for the Atoms tab — loads atoms, drives search and
/// metadata edits, and surfaces delegate callbacks for the parent to
/// drive live chat.
@MainActor
@Observable
final class AtomsFlowController {
    private(set) var state: AtomsFlowState
    private let history: AtomsHistoryClient
    private let invoker = AtomsCommandInvoker()

    var onOpenAtom: ((Atom) -> Void)?
    var onActiveAtomRenamed: ((UUID, String) -> Void)?
    var onActiveAtomDeleted: ((UUID) -> Void)?

    init(
        state: AtomsFlowState = AtomsFlowState(),
        history: AtomsHistoryClient = .preview
    ) {
        self.state = state
        self.history = history
    }

    func dispatch(_ command: any AtomsCommand) {
        invoker.invoke(command, on: &state)
    }

    func mirrorActiveAtomID(_ id: UUID?) {
        state.activeAtomID = id
    }

    func loadAtoms() async {
        if let entries = try? await history.listAtomEntries() {
            state.entries = AtomsFlowState.deduplicatedPinnedFirst(entries)
        }
        if let groups = try? await history.listGroups() {
            state.availableGroups = groups
        }
    }

    func selectAtom(_ atom: Atom) {
        onOpenAtom?(atom)
    }

    func pinAtom(_ atom: Atom) async {
        let currentValue = state.entries.first(where: { $0.atom.id == atom.id })?.atom.isPinned ?? false
        let newValue = !currentValue
        dispatch(AtomsPinToggledCommand(atomID: atom.id))
        try? await history.setPinned(atom.id, newValue)
    }

    func renameAtom(id: UUID, title: String) async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let wasActive = id == state.activeAtomID
        dispatch(AtomsRenamedCommand(id: id, title: title))
        if wasActive { onActiveAtomRenamed?(id, trimmed) }
        try? await history.renameAtom(id, trimmed)
    }

    func deleteAtom(id: UUID) async {
        let wasActive = id == state.activeAtomID
        dispatch(AtomsDeletedCommand(id: id))
        if wasActive { onActiveAtomDeleted?(id) }
        try? await history.deleteAtom(id)
        if let groups = try? await history.listGroups() {
            state.availableGroups = groups
        }
    }

    func changeGroup(id: UUID, group: String?) async {
        dispatch(AtomsGroupChangedCommand(id: id, group: group))
        try? await history.setGroup(id, group)
        if let groups = try? await history.listGroups() {
            state.availableGroups = groups
        }
    }
}
