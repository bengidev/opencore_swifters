import Foundation
import Testing

@testable import OpenCore

@MainActor
@Suite("Atoms Section Grouping")
struct AtomsSectionTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func entry(
        preview: String,
        createdDaysAgo days: Double,
        lastMessageHoursAgo hours: Double = 0,
        isPinned: Bool = false,
        groupName: String? = nil
    ) -> AtomListEntry {
        let createdAt = now.addingTimeInterval(-days * 86_400 - 10)
        let lastMessageAt = now.addingTimeInterval(-hours * 3_600)
        return AtomListEntry(
            atom: Atom(
                id: UUID(),
                title: preview,
                createdAt: createdAt,
                updatedAt: lastMessageAt,
                isPinned: isPinned,
                groupName: groupName
            ),
            lastMessagePreview: preview,
            lastMessageAt: lastMessageAt
        )
    }

    @Test("Pinned atoms collapse into a leading Pinned section")
    func pinnedSectionLeadsAndExcludesFromDateBuckets() {
        let entries = [
            entry(preview: "Pinned chat", createdDaysAgo: 3, isPinned: true),
            entry(preview: "Today chat", createdDaysAgo: 0)
        ]
        let sections = AtomsSection.grouped(entries, now: now)

        #expect(sections.first?.title == "Pinned")
        #expect(sections.first?.entries.count == 1)
        let nonPinned = sections.dropFirst().flatMap(\.entries)
        #expect(nonPinned.allSatisfy { !$0.atom.isPinned })
    }

    @Test("Ungrouped atoms bucket by created date")
    func createdDateBuckets() {
        let entries = [
            entry(preview: "today", createdDaysAgo: 0),
            entry(preview: "yesterday", createdDaysAgo: 1)
        ]
        let titles = AtomsSection.grouped(entries, now: now).map(\.title)
        #expect(titles == ["Today", "Yesterday"])
    }

    @Test("Collapsed groups can be force-expanded for search results")
    func forceExpandedGroupsExposeMatchingEntries() {
        let entries = [
            entry(preview: "Needle", createdDaysAgo: 0, groupName: "Work")
        ]

        let collapsed = AtomsSection.grouped(entries, now: now)
        #expect(collapsed.first?.title == ">:Work")
        #expect(collapsed.first?.entries.isEmpty == true)

        let expandedForSearch = AtomsSection.grouped(
            entries,
            now: now,
            forceExpandGroups: true
        )
        #expect(expandedForSearch.first?.title == "v:Work")
        #expect(expandedForSearch.first?.entries.map(\.lastMessagePreview) == ["Needle"])
    }

    @Test("Relative label uses full style")
    func relativeLabelFullStyle() {
        let label = AtomsSection.relativeLabel(
            for: now.addingTimeInterval(-3_600),
            now: now
        )
        #expect(label.localizedCaseInsensitiveContains("hour"))
    }
}
