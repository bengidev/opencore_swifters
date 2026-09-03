import SwiftUI

/// Full-screen Atoms list with search, grouped rows, and metadata actions.
struct AtomsListView: View {
    @Bindable var flow: AtomsFlowController

    @Environment(\.sharedPalette) private var palette

    @State private var renameTarget: Atom?
    @State private var renameText: String = ""
    @State private var newGroupText: String = ""
    @State private var newGroupTargetID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchField
            Divider()
                .overlay(palette.textTertiary.opacity(0.25))

            if flow.state.entries.isEmpty {
                emptyState
            } else if flow.state.filteredEntries.isEmpty {
                noResultsState
            } else {
                atomList
            }
        }
        .navigationTitle("Atoms")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await flow.loadAtoms()
        }
        .alert("Rename atom", isPresented: renameAlertBinding) {
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) { renameTarget = nil }
            Button("Save") {
                if let target = renameTarget {
                    Task { await flow.renameAtom(id: target.id, title: renameText) }
                }
                renameTarget = nil
            }
        }
        .alert("Create Group", isPresented: Binding(
            get: { newGroupTargetID != nil },
            set: { if !$0 { newGroupTargetID = nil } }
        )) {
            TextField("Group name", text: $newGroupText)
            Button("Cancel", role: .cancel) {
                newGroupTargetID = nil
            }
            Button("Create") {
                if let targetID = newGroupTargetID {
                    let trimmed = newGroupText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        Task { await flow.changeGroup(id: targetID, group: trimmed) }
                    }
                    newGroupTargetID = nil
                }
            }
        }
        .background(palette.surfaceBase)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.textTertiary)

            TextField(
                "Search atoms",
                text: Binding(
                    get: { flow.state.searchQuery },
                    set: { flow.dispatch(AtomsSearchQueryChangedCommand(query: $0)) }
                )
            )
            .font(.system(size: 15))
            .foregroundStyle(palette.textPrimary)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)

            if !flow.state.searchQuery.isEmpty {
                Button {
                    flow.dispatch(AtomsSearchQueryChangedCommand(query: ""))
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(palette.textTertiary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous).fill(palette.surfaceSubtle)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var emptyState: some View {
        centeredState(
            icon: "atom",
            title: "No atoms yet",
            subtitle: "Your conversations will appear here."
        )
    }

    private var noResultsState: some View {
        centeredState(
            icon: "magnifyingglass",
            title: "No matches",
            subtitle: "No atoms match your search."
        )
    }

    private func centeredState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(palette.textTertiary)
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.textSecondary)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(palette.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    private var atomList: some View {
        ScrollView(.vertical) {
            atomListContent
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
    }

    private var listIdentity: String {
        flow.state.filteredEntries
            .map {
                "\($0.id):\($0.lastMessagePreview):\($0.atom.isPinned):\($0.atom.groupName ?? ""):\($0.lastMessageAt.timeIntervalSinceReferenceDate)"
            }
            .joined(separator: "|")
    }

    private func liveEntry(id: UUID) -> AtomListEntry? {
        flow.state.filteredEntries.first { $0.id == id }
    }

    @ViewBuilder
    private var atomListContent: some View {
        LazyVStack(alignment: .leading, spacing: 4, pinnedViews: [.sectionHeaders]) {
            ForEach(AtomsSection.grouped(
                flow.state.filteredEntries,
                expandedGroups: flow.state.expandedGroups,
                forceExpandGroups: !flow.state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )) { section in
                Section {
                    ForEach(section.entries) { entry in
                        Button {
                            let live = liveEntry(id: entry.id) ?? entry
                            flow.selectAtom(live.atom)
                        } label: {
                            atomRow(
                                entry,
                                isInGroup: section.id.hasPrefix("group:")
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu { rowMenu(entry) }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .id("\(section.id)-\(entry.id)")
                    }
                } header: {
                    groupSectionHeader(section)
                }
            }
        }
        .id(listIdentity)
    }

    @ViewBuilder
    private func groupSectionHeader(_ section: AtomsSection) -> some View {
        if section.id.hasPrefix("group:") {
            let groupName = String(section.id.dropFirst("group:".count))
            let isExpanded = flow.state.expandedGroups.contains(groupName)
            Button {
                _ = withAnimation(.easeInOut(duration: 0.22)) {
                    flow.dispatch(AtomsGroupHeaderToggledCommand(group: groupName))
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.accentSoft)
                    Text(groupName.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.textSecondary)
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(palette.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            sectionHeader(section.title)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(palette.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 4)
            .background(palette.surfaceBase)
    }

    @ViewBuilder
    private func rowMenu(_ entry: AtomListEntry) -> some View {
        let live = liveEntry(id: entry.id) ?? entry
        Button {
            renameTarget = live.atom
            renameText = live.atom.title
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        Button {
            _ = withAnimation(.easeInOut(duration: 0.22)) {
                Task { await flow.pinAtom(live.atom) }
            }
        } label: {
            Label(
                live.atom.isPinned ? "Unpin" : "Pin",
                systemImage: live.atom.isPinned ? "pin.slash" : "pin"
            )
        }
        Menu {
            ForEach(flow.state.availableGroups, id: \.self) { group in
                Button(group) {
                    Task {
                        await flow.changeGroup(
                            id: live.atom.id,
                            group: live.atom.groupName == group ? nil : group
                        )
                    }
                }
            }
            if let currentGroup = live.atom.groupName {
                Button(role: .destructive) {
                    Task { await flow.changeGroup(id: live.atom.id, group: nil) }
                } label: {
                    Label("Remove from \(currentGroup)", systemImage: "folder.badge.minus")
                }
            }
            Divider()
            Button {
                newGroupTargetID = live.atom.id
                newGroupText = ""
            } label: {
                Label("New Group...", systemImage: "folder.badge.plus")
            }
        } label: {
            Label(
                live.atom.groupName == nil ? "Move to Group" : "Group: \(live.atom.groupName!)",
                systemImage: "folder"
            )
        }
        Button(role: .destructive) {
            Task { await flow.deleteAtom(id: live.atom.id) }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func atomRow(
        _ entry: AtomListEntry,
        isInGroup: Bool
    ) -> some View {
        let live = liveEntry(id: entry.id) ?? entry
        let isActive = flow.state.activeAtomID == live.atom.id
        return HStack(spacing: 8) {
            if live.atom.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.textTertiary)
            }
            if !isInGroup, live.atom.groupName != nil {
                Image(systemName: "folder.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.accentSoft)
            }
            Text(live.lastMessagePreview)
                .font(.system(size: 15, weight: isActive ? .semibold : .regular))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            Text(AtomsSection.relativeLabel(for: live.lastMessageAt))
                .font(.system(size: 12))
                .foregroundStyle(palette.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, isInGroup ? 18 : 0)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isActive ? palette.surfaceSubtle : .clear)
        )
        .contentShape(Rectangle())
        .accessibilityIdentifier("atom-row")
    }

    private var renameAlertBinding: Binding<Bool> {
        Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )
    }
}

#Preview {
    NavigationStack {
        AtomsListView(flow: AtomsFlowController())
    }
    .environment(\.sharedPalette, SharedOpenCorePalette.resolve(.light))
}
