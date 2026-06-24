import SwiftUI

/// Prompt panel with context rail, speed/model chips, and send action.
struct HomeComposerView: View {
    @Bindable var home: HomeFlowController
    @Bindable var chat: ChatFlowController
    let isComposerFocused: FocusState<Bool>.Binding

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        VStack(spacing: 8) {
            HomeComposerPromptPanel(
                home: home,
                chat: chat,
                isComposerFocused: isComposerFocused
            )
            HomeComposerContextRail(
                home: home,
                dismissKeyboard: dismissKeyboard
            )
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(palette.surfaceBase)
    }

    private func dismissKeyboard() {
        isComposerFocused.wrappedValue = false
    }
}

private struct HomeComposerPromptPanel: View {
    @Bindable var home: HomeFlowController
    @Bindable var chat: ChatFlowController
    let isComposerFocused: FocusState<Bool>.Binding

    @Environment(\.sharedPalette) private var palette
    @State private var sendFeedbackTrigger = false

    private var canSend: Bool {
        !chat.state.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !chat.state.isSending
            && home.state.hasAPIKey
            && home.state.hasSelectedModel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !home.state.hasAPIKey {
                MissingAPIKeyHint { home.onOpenSettings?() }
            }

            TextField(
                "Ask anything... @files, $skills, /commands",
                text: Binding(
                    get: { chat.state.draftMessage },
                    set: { chat.setDraftMessage($0) }
                ),
                axis: .vertical
            )
            .frame(minHeight: 50)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(palette.textPrimary)
            .lineLimit(1...5)
            .textInputAutocapitalization(.sentences)
            .focused(isComposerFocused)

            HStack(spacing: 6) {
                HomeComposerIconButton(
                    systemImage: "plus",
                    accessibilityLabel: "Add attachment",
                    action: dismissKeyboard
                )

                Spacer(minLength: 4)

                HomeComposerIconButton(
                    systemImage: "mic",
                    accessibilityLabel: "Start voice input",
                    action: dismissKeyboard
                )

                HomeComposerSendButton(canSend: canSend, action: send)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .homeComposerGlass(cornerRadius: 28, shadowOpacity: 0.16)
        .sensoryFeedback(.success, trigger: sendFeedbackTrigger)
    }

    private func send() {
        guard canSend else { return }
        dismissKeyboard()
        sendFeedbackTrigger.toggle()
        Task { await chat.sendMessage(providerSortBy: home.state.activeProviderSortBy) }
    }

    private func dismissKeyboard() {
        isComposerFocused.wrappedValue = false
    }
}

private struct HomeComposerContextRail: View {
    @Bindable var home: HomeFlowController
    let dismissKeyboard: () -> Void

    @State private var isContextUsagePresented = false

    var body: some View {
        VStack(spacing: 8) {
            if home.state.hasAPIKey,
               !home.state.isModelCatalogAvailable,
               let catalogError = home.state.catalogError {
                CatalogUnavailableHint(message: catalogError)
            }

            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    HomeComposerModelButton(
                        title: home.state.modelPickerTitle,
                        isEnabled: home.state.isModelCatalogAvailable,
                        dismissKeyboard: dismissKeyboard
                    ) {
                        dismissKeyboard()
                        home.setModelPopupPresented(true)
                    }
                    .accessibilityLabel(
                        home.state.isModelCatalogAvailable
                            ? "Model, \(home.state.modelPickerTitle)"
                            : "Model, not available"
                    )

                    if home.state.selectedModelOption?.supportsReasoning == true {
                        HomeComposerMenuChip(
                            title: home.state.reasoningModel.title,
                            systemImage: "circle.hexagongrid",
                            minWidth: 92,
                            dismissKeyboard: dismissKeyboard
                        ) {
                            Section("Reasoning") {
                                ForEach(SidePanelReasoningModel.allCases) { level in
                                    Button {
                                        dismissKeyboard()
                                        home.selectReasoningModel(level)
                                    } label: {
                                        Label(
                                            level.title,
                                            systemImage: home.state.reasoningModel == level ? "checkmark" : "circle"
                                        )
                                    }
                                }
                            }
                        }
                        .accessibilityLabel("Reasoning, \(home.state.reasoningModel.title)")
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    if let speedModes = home.state.selectedModelOption?.availableSpeedModes,
                       !speedModes.isEmpty {
                        HomeComposerMenuChip(
                            title: home.state.speedMode.title,
                            systemImage: home.state.speedMode.systemImage,
                            displaysTitle: false,
                            displaysChevron: false,
                            isSignal: home.state.speedMode == .fast,
                            minWidth: 38,
                            dismissKeyboard: dismissKeyboard
                        ) {
                            Section("Speed") {
                                ForEach(speedModes) { speedMode in
                                    Button {
                                        dismissKeyboard()
                                        home.selectSpeedMode(speedMode)
                                    } label: {
                                        Label(speedMode.title, systemImage: speedMode.systemImage)
                                    }
                                }
                            }
                        }
                        .accessibilityLabel("Speed, \(home.state.speedMode.title)")
                    }

                    HomeComposerContextUsageButton(
                        usage: home.state.contextUsage,
                        isPresented: $isContextUsagePresented,
                        dismissKeyboard: dismissKeyboard
                    )
                }
            }
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 4)
        .overlay(alignment: .bottomTrailing) {
            if isContextUsagePresented {
                HomeComposerContextUsagePopover(usage: home.state.contextUsage)
                    .offset(x: -2, y: -46)
                    .transition(.opacity)
                    .zIndex(2)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .animation(.easeInOut(duration: 0.16), value: isContextUsagePresented)
    }
}

private struct CatalogUnavailableHint: View {
    let message: String

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 13, weight: .semibold))
                .accessibilityHidden(true)

            Text(message)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .foregroundStyle(palette.textSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.surfaceSubtle.opacity(palette.isDark ? 0.5 : 0.8))
        }
        .accessibilityLabel("Model catalog unavailable, \(message)")
    }
}

private struct MissingAPIKeyHint: View {
    let openSettings: () -> Void

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        Button(action: openSettings) {
            HStack(spacing: 8) {
                Image(systemName: "key.slash")
                    .font(.system(size: 13, weight: .semibold))
                    .accessibilityHidden(true)

                Text("Add an API key in Settings to start sending")
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 6)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(palette.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(palette.surfaceSubtle.opacity(palette.isDark ? 0.5 : 0.8))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(palette.lineSoft.opacity(palette.isDark ? 0.45 : 0.6), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add an API key in Settings to start sending")
        .accessibilityIdentifier("composer-missing-key-hint")
    }
}

private struct HomeComposerMenuChip<MenuItems: View>: View {
    let title: String
    let systemImage: String?
    let displaysTitle: Bool
    let displaysChevron: Bool
    let isSignal: Bool
    let minWidth: CGFloat
    let dismissKeyboard: () -> Void
    let menuItems: MenuItems

    @Environment(\.sharedPalette) private var palette

    init(
        title: String,
        systemImage: String? = nil,
        displaysTitle: Bool = true,
        displaysChevron: Bool = true,
        isSignal: Bool = false,
        minWidth: CGFloat = 0,
        dismissKeyboard: @escaping () -> Void = {},
        @ViewBuilder menuItems: () -> MenuItems
    ) {
        self.title = title
        self.systemImage = systemImage
        self.displaysTitle = displaysTitle
        self.displaysChevron = displaysChevron
        self.isSignal = isSignal
        self.minWidth = minWidth
        self.dismissKeyboard = dismissKeyboard
        self.menuItems = menuItems()
    }

    var body: some View {
        Menu {
            menuItems
        } label: {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .accessibilityHidden(true)
                }

                if displaysTitle {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                if displaysChevron {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(isSignal ? palette.accentPrimary : palette.textSecondary)
            .frame(minWidth: minWidth)
            .frame(height: 30)
            .padding(.horizontal, displaysTitle ? 10 : 8)
            .homeComposerGlass(cornerRadius: 16, shadowOpacity: 0.06)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture().onEnded { dismissKeyboard() }
        )
    }
}

private struct HomeComposerContextUsageButton: View {
    let usage: ContextWindowUsage
    @Binding var isPresented: Bool
    let dismissKeyboard: () -> Void

    var body: some View {
        Button {
            dismissKeyboard()
            isPresented.toggle()
        } label: {
            HomeComposerContextUsageIndicator(usage: usage)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Context usage")
        .accessibilityValue(usage.accessibilitySummary)
    }
}

private struct HomeComposerContextUsageIndicator: View {
    let usage: ContextWindowUsage

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        ZStack {
            Circle()
                .fill(palette.surfaceRaised.opacity(palette.isDark ? 0.42 : 0.72))

            Circle()
                .stroke(palette.accentPrimary.opacity(palette.isDark ? 0.14 : 0.12), lineWidth: 3)
                .frame(width: 23, height: 23)

            Circle()
                .trim(from: 0, to: usage.fractionUsed)
                .stroke(
                    palette.accentPrimary.opacity(palette.isDark ? 0.92 : 0.82),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 23, height: 23)

            Text(usage.ringCenterLabel)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(palette.accentPrimary)
        }
        .frame(width: 38, height: 38)
        .background(.ultraThinMaterial, in: Circle())
        .overlay {
            Circle()
                .stroke(palette.accentPrimary.opacity(palette.isDark ? 0.18 : 0.12), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

private struct HomeComposerContextUsagePopover: View {
    let usage: ContextWindowUsage

    @Environment(\.sharedPalette) private var palette

    private let cornerRadius: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text("Context window")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: 12)

                Text(usage.popoverBadgeText)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(usage.showsUsageBreakdown ? palette.accentPrimary : palette.textSecondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background {
                        if usage.showsUsageBreakdown {
                            Capsule()
                                .fill(palette.accentSoft.opacity(palette.isDark ? 0.35 : 1))
                        }
                    }
            }

            if usage.showsUsageBreakdown {
                contextProgressBar
            }

            VStack(alignment: .leading, spacing: 8) {
                contextMetricRow(label: "Free", value: usage.hasKnownLimit ? usage.tokensRemainingFormatted : "—")
                contextMetricRow(label: "Used", value: usage.tokensUsedFormatted)
                contextMetricRow(label: "Total", value: usage.hasKnownLimit ? usage.tokenLimitFormatted : "—")
            }

            if usage.showsUsageBreakdown {
                HStack(spacing: 10) {
                    Text("\(usage.percentUsed)% used")
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Spacer(minLength: 8)

                    Text("\(usage.percentRemaining)% left")
                        .foregroundStyle(palette.textTertiary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .fixedSize(horizontal: true, vertical: false)
        .frame(minWidth: 240, maxWidth: 300)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(palette.isDark ? palette.surfacePaper.opacity(0.78) : palette.surfaceRaised.opacity(0.82))
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(palette.lineSoft.opacity(palette.isDark ? 0.45 : 0.65), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 8)
    }

    private var contextProgressBar: some View {
        GeometryReader { geometry in
            let totalWidth = max(geometry.size.width, 1)
            let clampedProgress = min(max(usage.fractionUsed, 0), 1)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(palette.lineSoft.opacity(palette.isDark ? 0.35 : 0.55))

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(palette.accentPrimary.opacity(palette.isDark ? 0.92 : 0.82))
                    .frame(width: totalWidth * CGFloat(clampedProgress))
            }
        }
        .frame(height: 10)
    }

    private func contextMetricRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(label):")
                .foregroundStyle(palette.textSecondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 8)

            Text(value)
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .font(.system(size: 11, weight: .medium, design: .monospaced))
    }
}

private struct HomeComposerIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.textTertiary)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct HomeComposerSendButton: View {
    let canSend: Bool
    let action: () -> Void

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(canSend ? palette.controlStrongText : palette.textTertiary)
                .frame(width: 34, height: 34)
                .background(canSend ? palette.controlStrong : palette.surfaceSubtle.opacity(0.9))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .accessibilityLabel("Send message")
    }
}

private struct HomeComposerGlassChrome: ViewModifier {
    let cornerRadius: CGFloat
    let shadowOpacity: Double

    @Environment(\.sharedPalette) private var palette

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(palette.isDark ? palette.surfacePaper.opacity(0.7) : palette.surfaceRaised.opacity(0.72))
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(palette.lineSoft.opacity(palette.isDark ? 0.35 : 0.55), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(shadowOpacity), radius: 18, x: 0, y: 8)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private extension View {
    func homeComposerGlass(cornerRadius: CGFloat, shadowOpacity: Double) -> some View {
        modifier(HomeComposerGlassChrome(cornerRadius: cornerRadius, shadowOpacity: shadowOpacity))
    }
}

private struct HomeComposerModelButton: View {
    let title: String
    let isEnabled: Bool
    let dismissKeyboard: () -> Void
    let action: () -> Void

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .accessibilityHidden(true)

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if isEnabled {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(isEnabled ? palette.textSecondary : palette.textTertiary)
            .frame(minWidth: 104)
            .frame(height: 30)
            .padding(.horizontal, 10)
            .homeComposerGlass(cornerRadius: 16, shadowOpacity: 0.06)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .simultaneousGesture(
            TapGesture().onEnded { dismissKeyboard() }
        )
    }
}

#Preview {
    struct PreviewHost: View {
        @FocusState private var isComposerFocused: Bool

        var body: some View {
            ZStack {
                SharedOpenCorePalette.resolve(.light).surfaceBase.ignoresSafeArea()
                HomeComposerView(
                    home: HomeFlowController(
                        credentialStore: SidePanelInMemoryCredentialStore(),
                        providerPreference: SidePanelInMemoryProviderPreferenceStore()
                    ),
                    chat: ChatFlowController(),
                    isComposerFocused: $isComposerFocused
                )
            }
            .environment(\.sharedPalette, SharedOpenCorePalette.resolve(.light))
        }
    }

    return PreviewHost()
}
