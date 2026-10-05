import Foundation
import Testing

@testable import OpenCore

@MainActor
@Suite("Atoms Flow Controller")
struct AtomsFlowControllerTests {
    private actor Recorder {
        var entries: [AtomListEntry]
        var groups: [String]
        var pinned: [(id: UUID, value: Bool)] = []
        var renamed: [(id: UUID, title: String)] = []
        var grouped: [(id: UUID, group: String?)] = []
        var deleted: [UUID] = []

        init(_ seed: [AtomListEntry], groups: [String] = []) {
            self.entries = seed
            self.groups = groups
        }

        func list() -> [AtomListEntry] { entries }
        func listGroups() -> [String] { groups }
        func setPinned(_ id: UUID, _ value: Bool) { pinned.append((id, value)) }
        func rename(_ id: UUID, _ title: String) { renamed.append((id, title)) }
        func setGroup(_ id: UUID, _ group: String?) { grouped.append((id, group)) }
        func delete(_ id: UUID) { deleted.append(id) }
    }

    private func makeClient(_ recorder: Recorder) -> AtomsHistoryClient {
        AtomsHistoryClient(
            listAtomEntries: { await recorder.list() },
            listAtoms: { await recorder.list().map(\.atom) },
            loadMessages: { _ in [] },
            saveAtom: { _ in },
            appendMessage: { _, _ in },
            deleteAtom: { await recorder.delete($0) },
            setPinned: { await recorder.setPinned($0, $1) },
            renameAtom: { await recorder.rename($0, $1) },
            setGroup: { await recorder.setGroup($0, $1) },
            listGroups: { await recorder.listGroups() }
        )
    }

    private func entry(_ title: String, id: UUID = UUID(), pinned: Bool = false) -> AtomListEntry {
        let now = Date()
        return AtomListEntry(
            atom: Atom(id: id, title: title, createdAt: now, updatedAt: now, isPinned: pinned),
            lastMessagePreview: title,
            lastMessageAt: now
        )
    }

    @Test("loadAtoms loads persisted entries")
    func loadAtomsFetchesEntries() async {
        let older = entry("Alpha", id: UUID())
        let newer = entry("Beta", id: UUID())
        let recorder = Recorder([older, newer])
        let controller = AtomsFlowController(history: makeClient(recorder))

        await controller.loadAtoms()

        #expect(controller.state.entries.map(\.lastMessagePreview).sorted() == ["Alpha", "Beta"])
    }

    @Test("Selecting an atom delegates open")
    func selectDelegatesOpen() async {
        let target = entry("Reopen me")
        let controller = AtomsFlowController(
            state: AtomsFlowState(entries: [target]),
            history: makeClient(Recorder([target]))
        )
        var opened: Atom?
        controller.onOpenAtom = { opened = $0 }

        controller.selectAtom(target.atom)

        #expect(opened?.title == "Reopen me")
    }

    @Test("Search query filters by preview")
    func searchFilters() {
        let controller = AtomsFlowController(
            state: AtomsFlowState(entries: [
                entry("Swift tips"),
                entry("Dinner ideas")
            ])
        )

        controller.dispatch(AtomsSearchQueryChangedCommand(query: "swift"))

        #expect(controller.state.filteredEntries.map(\.lastMessagePreview) == ["Swift tips"])
    }

    @Test("Renaming the active atom notifies the parent")
    func renameActiveAtomNotifiesParent() async {
        let target = entry("Old title")
        let recorder = Recorder([target])
        let controller = AtomsFlowController(
            state: AtomsFlowState(entries: [target], activeAtomID: target.atom.id),
            history: makeClient(recorder)
        )
        var renamed: (id: UUID, title: String)?
        controller.onActiveAtomRenamed = { renamed = ($0, $1) }

        await controller.renameAtom(id: target.atom.id, title: "New title")

        #expect(renamed?.id == target.atom.id)
        #expect(renamed?.title == "New title")
    }

    @Test("Renaming a background atom stays silent")
    func renameBackgroundAtomStaysSilent() async {
        let active = entry("Active")
        let background = entry("Background")
        let recorder = Recorder([active, background])
        let controller = AtomsFlowController(
            state: AtomsFlowState(entries: [active, background]),
            history: makeClient(recorder)
        )
        var renamed: (id: UUID, title: String)?
        controller.onActiveAtomRenamed = { renamed = ($0, $1) }

        await controller.renameAtom(id: background.atom.id, title: "Changed")

        #expect(renamed == nil)
    }

    @Test("Deleting the active atom notifies the parent")
    func deleteActiveAtomNotifiesParent() async {
        let target = entry("Doomed")
        let recorder = Recorder([target])
        let controller = AtomsFlowController(
            state: AtomsFlowState(entries: [target], activeAtomID: target.atom.id),
            history: makeClient(recorder)
        )
        var deletedID: UUID?
        controller.onActiveAtomDeleted = { deletedID = $0 }

        await controller.deleteAtom(id: target.atom.id)

        #expect(deletedID == target.atom.id)
    }

    @Test("Deleting a background atom stays silent")
    func deleteBackgroundAtomStaysSilent() async {
        let active = entry("Active")
        let background = entry("Background")
        let recorder = Recorder([active, background])
        let controller = AtomsFlowController(
            state: AtomsFlowState(entries: [active, background]),
            history: makeClient(recorder)
        )
        var deletedID: UUID?
        controller.onActiveAtomDeleted = { deletedID = $0 }

        await controller.deleteAtom(id: background.atom.id)

        #expect(deletedID == nil)
    }
}
