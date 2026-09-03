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

    private(set) var selectedProviderID: String

    var onOpenAtom: ((Atom) -> Void)?
    var onActiveAtomRenamed: ((UUID, String) -> Void)?
    var onActiveAtomDeleted: ((UUID) -> Void)?

    init(
        state: AtomsFlowState = AtomsFlowState(),
        history: AtomsHistoryClient = .preview,
        selectedProviderID: String = ProviderDescriptor.openRouter.id
    ) {
        self.state = state
        self.history = history
        self.selectedProviderID = selectedProviderID
    }

    func dispatch(_ command: any AtomsCommand) {
        let priorActiveID = state.activeAtomID
        invoker.invoke(command, on: &state)

        if let cmd = command as? AtomsRenamedCommand {
            let trimmed = cmd.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, cmd.id == priorActiveID {
                onActiveAtomRenamed?(cmd.id, trimmed)
            }
        }

        if let cmd = command as? AtomsDeletedCommand, cmd.id == priorActiveID {
            onActiveAtomDeleted?(cmd.id)
        }
    }

    func mirrorActiveAtomID(_ id: UUID?) {
        state.activeAtomID = id
    }

    func syncSelectedProviderID(_ id: String) {
        selectedProviderID = id
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
        dispatch(AtomsRenamedCommand(id: id, title: title))
        try? await history.renameAtom(id, trimmed)
    }

    func deleteAtom(id: UUID) async {
        dispatch(AtomsDeletedCommand(id: id))
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
