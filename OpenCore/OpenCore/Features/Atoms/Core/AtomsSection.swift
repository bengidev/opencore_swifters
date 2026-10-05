import Foundation

/// Section model for the Atoms list. Pinned atoms lead, then named groups,
/// then atoms grouped by their creation date.
struct AtomsSection: Identifiable, Equatable {
    /// What a section holds. The group name and its expansion live here so
    /// views never parse them out of an id or title string.
    enum Kind: Equatable {
        case pinned
        case group(name: String, expanded: Bool)
        case createdDate(Date)
    }

    let kind: Kind
    let title: String
    let entries: [AtomListEntry]

    var id: String {
        switch kind {
        case .pinned: "pinned"
        case .group(let name, _): "group:" + name
        case .createdDate(let day): "created:\(day.timeIntervalSinceReferenceDate)"
        }
    }

    var isGroup: Bool {
        if case .group = kind { return true }
        return false
    }

    var groupName: String? {
        if case .group(let name, _) = kind { return name }
        return nil
    }

    static func grouped(
        _ entries: [AtomListEntry],
        now: Date = Date(),
        calendar: Calendar = .current,
        expandedGroups: Set<String> = [],
        forceExpandGroups: Bool = false
    ) -> [AtomsSection] {
        var sections: [AtomsSection] = []

        let pinned = entries.filter(\.atom.isPinned)
        if !pinned.isEmpty {
            sections.append(AtomsSection(kind: .pinned, title: "Pinned", entries: pinned))
        }

        var groupBuckets: [String: [AtomListEntry]] = [:]
        var groupOrder: [String] = []
        for entry in entries where !entry.atom.isPinned && entry.atom.groupName != nil {
            guard let groupName = entry.atom.groupName else { continue }
            if groupBuckets[groupName] == nil { groupOrder.append(groupName) }
            groupBuckets[groupName, default: []].append(entry)
        }
        for groupName in groupOrder.sorted() {
            let groupEntries = groupBuckets[groupName] ?? []
            let isExpanded = forceExpandGroups || expandedGroups.contains(groupName)
            sections.append(
                AtomsSection(
                    kind: .group(name: groupName, expanded: isExpanded),
                    title: groupName,
                    entries: isExpanded ? groupEntries : []
                )
            )
        }

        var dateBuckets: [Date: [AtomListEntry]] = [:]
        var dateOrder: [Date] = []
        for entry in entries where !entry.atom.isPinned && entry.atom.groupName == nil {
            let day = calendar.startOfDay(for: entry.atom.createdAt)
            if dateBuckets[day] == nil { dateOrder.append(day) }
            dateBuckets[day, default: []].append(entry)
        }

        for day in dateOrder.sorted(by: >) {
            sections.append(
                AtomsSection(
                    kind: .createdDate(day),
                    title: createdDateLabel(for: day, now: now, calendar: calendar),
                    entries: dateBuckets[day] ?? []
                )
            )
        }

        return sections
    }

    /// Human-readable relative time, e.g. "just now", "1 hour ago".
    static func relativeLabel(for date: Date, now: Date = Date()) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }

    private static func createdDateLabel(
        for day: Date,
        now: Date,
        calendar: Calendar
    ) -> String {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        if calendar.isDate(day, inSameDayAs: startOfToday) { return "Today" }
        if calendar.isDate(day, inSameDayAs: startOfYesterday) { return "Yesterday" }
        return Self.mediumDateFormatter.string(from: day)
    }

    private static let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
