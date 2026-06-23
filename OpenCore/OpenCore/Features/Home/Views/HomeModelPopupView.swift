import SwiftUI

/// Full-screen sheet presenting the live model catalog with debounced search
/// and a free-tier filter.
struct HomeModelPopupView: View {
    @Bindable var home: HomeFlowController
    @Environment(\.sharedPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                if home.state.selectedProviderID == SidePanelProviderAPI.openRouter.id {
                    filterBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                Divider()
                    .overlay(palette.lineSoft)

                modelList
            }
            .background(palette.surfaceBase.ignoresSafeArea())
            .navigationTitle("Select model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        home.setModelPopupPresented(false)
                        dismiss()
                    }
                    .foregroundStyle(palette.textSecondary)
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.textTertiary)
                .accessibilityHidden(true)

            TextField("Search models…", text: Binding(
                get: { home.state.modelSearchQuery },
                set: { home.setModelSearchQuery($0) }
            ))
            .font(.system(size: 15))
            .foregroundStyle(palette.textPrimary)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .accessibilityLabel("Search models")

            if !home.state.modelSearchQuery.isEmpty {
                Button {
                    home.setModelSearchQuery("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(palette.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.surfaceSubtle.opacity(palette.isDark ? 0.6 : 0.9))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(palette.lineSoft.opacity(palette.isDark ? 0.4 : 0.55), lineWidth: 1)
        }
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            Toggle(isOn: Binding(
                get: { home.state.modelFilterFreeOnly },
                set: { home.setModelFilterFreeOnly($0) }
            )) {
                Label("Free only", systemImage: "star.circle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(
                        home.state.modelFilterFreeOnly
                            ? palette.accentPrimary
                            : palette.textSecondary
                    )
            }
            .toggleStyle(HomeModelFilterToggleStyle(palette: palette))
            .accessibilityLabel("Show free models only")

            Spacer()

            if !home.state.catalogModels.isEmpty {
                Text("\(home.state.filteredModels.count) models")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.textTertiary)
            }
        }
    }

    private var modelList: some View {
        Group {
            if home.state.filteredModels.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(home.state.filteredModels) { option in
                            HomeModelPopupRow(
                                option: option,
                                isSelected: home.state.selectedModelID == option.id,
                                palette: palette
                            ) {
                                home.selectModel(option.id)
                                dismiss()
                            }

                            if option.id != home.state.filteredModels.last?.id {
                                Divider()
                                    .overlay(palette.lineSoft.opacity(0.5))
                                    .padding(.leading, 56)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(palette.textTertiary)
                .accessibilityHidden(true)

            Text("No models found")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.textPrimary)

            Text("Try a different search term or remove the free-only filter.")
                .font(.system(size: 14))
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HomeModelPopupRow: View {
    let option: HomeModelOption
    let isSelected: Bool
    let palette: SharedOpenCorePalette
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected
                            ? palette.accentPrimary.opacity(palette.isDark ? 0.25 : 0.15)
                            : palette.surfaceSubtle.opacity(0.7)
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: isSelected ? "checkmark" : "sparkles")
                        .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? palette.accentPrimary : palette.textTertiary)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(option.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(1)

                        if option.isFree {
                            Text("FREE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(palette.accentPrimary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(palette.accentSoft.opacity(palette.isDark ? 0.3 : 0.9))
                                )
                        }
                    }

                    if let contextLength = option.contextLength {
                        Text(contextLengthLabel(contextLength))
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(palette.textTertiary)
                    }
                }

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            isSelected
                ? palette.accentSoft.opacity(palette.isDark ? 0.08 : 0.06)
                : Color.clear
        )
        .accessibilityLabel("\(option.title)\(option.isFree ? ", free" : "")\(isSelected ? ", selected" : "")")
    }

    private func contextLengthLabel(_ tokens: Int) -> String {
        let count = Double(tokens)
        if count >= 1_000_000 { return "\(Int(count / 1_000_000))M ctx" }
        if count >= 1_000 { return "\(Int(count / 1_000))K ctx" }
        return "\(tokens) ctx"
    }
}

private struct HomeModelFilterToggleStyle: ToggleStyle {
    let palette: SharedOpenCorePalette

    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            configuration.label
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(configuration.isOn
                            ? palette.accentSoft.opacity(palette.isDark ? 0.3 : 0.9)
                            : palette.surfaceSubtle.opacity(0.7)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
