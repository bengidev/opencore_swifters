import Foundation
import Testing

@testable import OpenCore

/// Tests for the side panel session flow controller. Ported from the TCA
/// `SidePanelSessionFeatureTests`. Verifies list loading on open, local title
/// filtering, pin/rename/delete persistence, and the delegate outputs the
/// parent relies on to drive the live chat reducer.
@MainActor
@Suite("Side Panel Session Flow Controller")
struct SidePanelSessionFlowControllerTests {

    /// A recording history client backed by an actor so the `@Sendable`
    /// closures can capture mutations safely under strict concurrency.
    private actor Recorder {
        var conversations: [SidePanelConversation]
        var groups: [String]
        var pinned: [(id: UUID, value: Bool)] = []
        var renamed: [(id: UUID, title: String)] = []
        var grouped: [(id: UUID, group: String?)] = []
        var deleted: [UUID] = []

        init(_ seed: [SidePanelConversation], groups: [String] = []) {
            self.conversations = seed
            self.groups = groups
        }

        func list() -> [SidePanelConversation] { conversations }
        func listGroups() -> [String] { groups }
        func setPinned(_ id: UUID, _ value: Bool) { pinned.append((id, value)) }
        func rename(_ id: UUID, _ title: String) { renamed.append((id, title)) }
        func setGroup(_ id: UUID, _ group: String?) { grouped.append((id, group)) }
        func delete(_ id: UUID) { deleted.append(id) }
    }

    private func makeClient(_ recorder: Recorder) -> SidePanelHistoryClient {
        SidePanelHistoryClient(
            listConversations: { await recorder.list() },
            loadMessages: { _ in [] },
            saveConversation: { _ in },
            appendMessage: { _, _ in },
            deleteConversation: { await recorder.delete($0) },
            setPinned: { await recorder.setPinned($0, $1) },
            renameConversation: { await recorder.rename($0, $1) },
            setGroup: { await recorder.setGroup($0, $1) },
            listGroups: { await recorder.listGroups() }
        )
    }

    private func conversation(
        _ title: String,
        id: UUID = UUID(),
        pinned: Bool = false,
        groupName: String? = nil
    ) -> SidePanelConversation {
        SidePanelConversation(id: id, title: title, isPinned: pinned, groupName: groupName)
    }

    private func makeController(
        recorder: Recorder,
        state: SidePanelSessionFlowState = .init()
    ) -> SidePanelSessionFlowController {
        SidePanelSessionFlowController(state: state, history: makeClient(recorder))
    }

    // MARK: - Toggle & Load

    @Test("Opening the drawer loads the persisted conversation list")
    func toggleLoadsConversations() async {
        let older = Date(timeIntervalSince1970: 1_000)
        let newer = Date(timeIntervalSince1970: 2_000)
        let seed = [
            SidePanelConversation(id: UUID(), title: "Alpha", updatedAt: older),
            SidePanelConversation(id: UUID(), title: "Beta", updatedAt: newer),
        ]
        let recorder = Recorder(seed)
        let controller = makeController(recorder: recorder)

        await controller.toggleSidebar()

        #expect(controller.state.isSidebarVisible == true)
        #expect(controller.state.conversations.map(\.title) == ["Beta", "Alpha"]) // most-recently-updated first
    }

    @Test("Loading conversations deduplicates by id keeping the pinned copy")
    func conversationsLoadedDeduplicates() async {
        let id = UUID()
        let unpinned = SidePanelConversation(id: id, title: "Unpinned", isPinned: false)
        let pinned = SidePanelConversation(id: id, title: "Pinned", isPinned: true)
        let recorder = Recorder([unpinned, pinned])
        let controller = makeController(recorder: recorder)

        await controller.toggleSidebar()

        #expect(controller.state.conversations.count == 1)
        #expect(controller.state.conversations[0].title == "Pinned")
    }

    @Test("Closing the drawer does not reload")
    func toggleClosedSkipsReload() async {
        let recorder = Recorder([])
        // Seed with some conversations so we can verify they weren't replaced.
        let controller = makeController(
            recorder: recorder,
            state: .init(isSidebarVisible: true, conversations: [conversation("Keep me")])
        )

        await controller.toggleSidebar()

        #expect(controller.state.isSidebarVisible == false)
        // Conversations unchanged since we closed, not opened.
        #expect(controller.state.conversations.count == 1)
    }

    // MARK: - Search

    @Test("Search query filters the loaded list by title, case-insensitively")
    func searchFilters() async {
        let controller = makeController(
            recorder: Recorder([]),
            state: .init(conversations: [conversation("Swift tips"), conversation("Dinner ideas")])
        )

        controller.dispatch(SidePanelSessionHistorySearchQueryChangedCommand(query: "swift"))

        #expect(controller.state.historySearchQuery == "swift")
        #expect(controller.state.filteredConversations.map(\.title) == ["Swift tips"])
    }

    // MARK: - Select

    @Test("Selecting a conversation closes the drawer and delegates open")
    func selectDelegatesOpen() async {
        let target = conversation("Reopen me")
        let controller = makeController(
            recorder: Recorder([target]),
            state: .init(isSidebarVisible: true, conversations: [target])
        )
        var opened: SidePanelConversation?
        controller.onOpenConversation = { opened = $0 }

        controller.selectConversation(target)

        #expect(controller.state.isSidebarVisible == false)
        #expect(opened?.title == "Reopen me")
    }

    // MARK: - Pin

    @Test("Pinning toggles state optimistically then persists fire-and-forget")
    func pinOptimisticUpdate() async {
        let target = conversation("Pin me")
        let recorder = Recorder([target])
        let controller = makeController(recorder: recorder, state: .init(conversations: [target]))

        await controller.pinConversation(target)

        #expect(controller.state.conversations.first?.isPinned == true)
        let pinned = await recorder.pinned
        #expect(pinned.count == 1)
        #expect(pinned.map(\.value) == [true])
    }

    @Test("Unpinning toggles state optimistically then persists fire-and-forget")
    func unpinOptimisticUpdate() async {
        let target = conversation("Unpin me", pinned: true)
        let recorder = Recorder([target])
        let controller = makeController(recorder: recorder, state: .init(conversations: [target]))

        await controller.pinConversation(target)

        #expect(controller.state.conversations.first?.isPinned == false)
        let pinned = await recorder.pinned
        #expect(pinned.map(\.value) == [false])
    }

    @Test("Pinning re-sorts conversations pinned-first")
    func pinResortsPinnedFirst() async {
        let unpinned = conversation("Later", id: UUID())
        let target = conversation("Pin me")
        let recorder = Recorder([unpinned, target])
        let controller = makeController(recorder: recorder, state: .init(conversations: [unpinned, target]))

        await controller.pinConversation(target)

        #expect(controller.state.conversations.map(\.title) == ["Pin me", "Later"])
    }

    // MARK: - Rename

    @Test("Renaming the active conversation delegates the new title")
    func renameActiveDelegates() async {
        let id = UUID()
        let target = conversation("Old", id: id)
        let recorder = Recorder([target])
        let controller = makeController(
            recorder: recorder,
            state: .init(conversations: [target], activeConversationID: id)
        )
        var renamedID: UUID?
        var renamedTitle: String?
        controller.onActiveConversationRenamed = { rID, rTitle in
            renamedID = rID
            renamedTitle = rTitle
        }

        await controller.renameConversation(id: id, title: "New")

        #expect(controller.state.conversations.first?.title == "New")
        #expect(renamedID == id)
        #expect(renamedTitle == "New")
        let recorded = await recorder.renamed
        #expect(recorded.map(\.title) == ["New"])
    }

    @Test("Renaming a non-active conversation persists without delegating")
    func renameInactiveNoDelegate() async {
        let id = UUID()
        let target = conversation("Old", id: id)
        let recorder = Recorder([target])
        let controller = makeController(
            recorder: recorder,
            state: .init(conversations: [target], activeConversationID: UUID())
        )
        var delegateFired = false
        controller.onActiveConversationRenamed = { _, _ in delegateFired = true }

        await controller.renameConversation(id: id, title: "New")

        #expect(controller.state.conversations.first?.title == "New")
        #expect(delegateFired == false)
        let recorded = await recorder.renamed
        #expect(recorded.map(\.title) == ["New"])
    }

    @Test("Renaming re-sorts conversations by updatedAt within pin tier")
    func renameResortsUnpinnedFirst() async {
        let olderDate = Date(timeIntervalSince1970: 1_000)
        let newerDate = Date(timeIntervalSince1970: 2_000)
        let older = SidePanelConversation(id: UUID(), title: "Older", updatedAt: olderDate)
        let targetID = UUID()
        let target = SidePanelConversation(id: targetID, title: "Target", updatedAt: newerDate)
        let recorder = Recorder([older, target])
        let controller = makeController(recorder: recorder, state: .init(conversations: [older, target]))

        await controller.renameConversation(id: targetID, title: "Renamed")

        #expect(controller.state.conversations.map(\.title) == ["Renamed", "Older"])
    }

    @Test("Renaming updates all duplicate ids in memory")
    func renameUpdatesDuplicateIds() async {
        let id = UUID()
        let first = SidePanelConversation(id: id, title: "Old A", isPinned: false)
        let second = SidePanelConversation(id: id, title: "Old B", isPinned: true)
        let recorder = Recorder([first, second])
        let controller = makeController(recorder: recorder, state: .init(conversations: [first, second]))

        await controller.renameConversation(id: id, title: "Unified")

        #expect(controller.state.conversations.allSatisfy { $0.id != id || $0.title == "Unified" })
        #expect(controller.state.filteredConversations.count == 1)
        #expect(controller.state.filteredConversations[0].title == "Unified")
        #expect(controller.state.filteredConversations[0].isPinned == true)
    }

    @Test("Renaming preserves pin state optimistically")
    func renamePreservesPinState() async {
        let unpinnedID = UUID()
        let pinnedID = UUID()
        let unpinned = conversation("Unpinned", id: unpinnedID)
        let pinned = conversation("Pinned", id: pinnedID, pinned: true)
        let recorder = Recorder([unpinned, pinned])
        let controller = makeController(recorder: recorder, state: .init(conversations: [unpinned, pinned]))

        await controller.renameConversation(id: unpinnedID, title: "Renamed unpinned")
        #expect(controller.state.conversations.first(where: { $0.id == unpinnedID })?.isPinned == false)

        await controller.renameConversation(id: pinnedID, title: "Renamed pinned")
        #expect(controller.state.conversations.first(where: { $0.id == pinnedID })?.isPinned == true)
    }

    // MARK: - Delete

    @Test("Deleting the active conversation delegates a clear")
    func deleteActiveDelegates() async {
        let id = UUID()
        let target = conversation("Doomed", id: id)
        let recorder = Recorder([target])
        let controller = makeController(
            recorder: recorder,
            state: .init(conversations: [target], activeConversationID: id)
        )
        var deletedID: UUID?
        controller.onActiveConversationDeleted = { deletedID = $0 }

        await controller.deleteConversation(id: id)

        #expect(controller.state.conversations.isEmpty)
        #expect(deletedID == id)
        let recorded = await recorder.deleted
        #expect(recorded == [id])
    }

    @Test("Deleting a non-active conversation persists without delegating")
    func deleteInactiveNoDelegate() async {
        let id = UUID()
        let target = conversation("Doomed", id: id)
        let recorder = Recorder([target])
        let controller = makeController(
            recorder: recorder,
            state: .init(conversations: [target], activeConversationID: UUID())
        )
        var delegateFired = false
        controller.onActiveConversationDeleted = { _ in delegateFired = true }

        await controller.deleteConversation(id: id)

        #expect(controller.state.conversations.isEmpty)
        #expect(delegateFired == false)
        let recorded = await recorder.deleted
        #expect(recorded == [id])
    }

    @Test("Deleting reloads available groups")
    func deleteReloadsGroups() async {
        let id = UUID()
        let target = conversation("Doomed", id: id, groupName: "Work")
        let recorder = Recorder([target], groups: ["Archive"])
        let controller = makeController(
            recorder: recorder,
            state: .init(conversations: [target], activeConversationID: UUID())
        )

        await controller.deleteConversation(id: id)

        #expect(controller.state.conversations.isEmpty)
        #expect(controller.state.availableGroups == ["Archive"])
        let recorded = await recorder.deleted
        #expect(recorded == [id])
    }

    // MARK: - Group change

    @Test("Grouping a conversation persists the group assignment")
    func groupChangePersistsOptimistically() async {
        let target = conversation("To Group")
        let recorder = Recorder([target])
        let controller = makeController(recorder: recorder, state: .init(conversations: [target]))

        await controller.changeGroup(id: target.id, group: "Work")

        #expect(controller.state.expandedGroups.contains("Work"))
        #expect(controller.state.conversations.first?.groupName == "Work")
        let recorded = await recorder.grouped
        #expect(recorded.count == 1)
        #expect(recorded.first?.id == target.id)
        #expect(recorded.first?.group == "Work")
    }

    @Test("Group header toggle expands/collapses")
    func groupHeaderExpandCollapse() async {
        let controller = makeController(recorder: Recorder([]))

        controller.dispatch(SidePanelSessionGroupHeaderToggledCommand(group: "Work"))
        #expect(controller.state.expandedGroups.contains("Work"))

        controller.dispatch(SidePanelSessionGroupHeaderToggledCommand(group: "Work"))
        #expect(!controller.state.expandedGroups.contains("Work"))
    }

    @Test("Removing a group sets groupName to nil")
    func removeGroup() async {
        let target = conversation("Grouped", groupName: "Work")
        let recorder = Recorder([target])
        let controller = makeController(recorder: recorder, state: .init(conversations: [target]))

        await controller.changeGroup(id: target.id, group: nil)

        #expect(controller.state.conversations.first?.groupName == nil)
        let recorded = await recorder.grouped
        #expect(recorded.count == 1)
        #expect(recorded.first?.id == target.id)
        #expect(recorded.first?.group == nil)
    }

    // MARK: - Deduplication edge cases

    @Test("filteredConversations deduplicates by id keeping the pinned copy")
    func filteredConversationsDeduplicatesPinnedFirst() {
        let id = UUID()
        let unpinned = SidePanelConversation(id: id, title: "Unpinned", isPinned: false)
        let pinned = SidePanelConversation(id: id, title: "Pinned", isPinned: true)
        let state = SidePanelSessionFlowState(conversations: [unpinned, pinned])
        let result = state.filteredConversations
        #expect(result.count == 1)
        #expect(result[0].title == "Pinned")
        #expect(result[0].isPinned == true)
    }

    @Test("filteredConversations deduplication preserves search filtering")
    func filteredConversationsDeduplicatesWithSearch() {
        let id = UUID()
        let first = SidePanelConversation(id: id, title: "Swift tips", isPinned: false)
        let second = SidePanelConversation(id: id, title: "Swift tips dup", isPinned: true)
        var state = SidePanelSessionFlowState(conversations: [first, second])
        state.historySearchQuery = "swift"
        let result = state.filteredConversations
        #expect(result.count == 1)
        #expect(result[0].title == "Swift tips dup")
        #expect(result[0].isPinned == true)
    }
}
