import SwiftUI

struct HomeComposerView: View {
    @Binding var draftMessage: String
    @Binding var speedMode: HomeComposerSpeedMode
    let selectedModelTitle: String
    let contextUsage: HomeComposerContextUsage
    let availableSpeedModes: [HomeComposerSpeedMode]
    let isComposerFocused: FocusState<Bool>.Binding

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        VStack(spacing: 8) {
            HomeComposerPromptPanel(
                draftMessage: $draftMessage,
                isComposerFocused: isComposerFocused
            )
            HomeComposerContextRail(
                selectedModelTitle: selectedModelTitle,
                speedMode: $speedMode,
                availableSpeedModes: availableSpeedModes,
                contextUsage: contextUsage,
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
    @Binding var draftMessage: String
    let isComposerFocused: FocusState<Bool>.Binding

    @Environment(\.sharedPalette) private var palette
    @State private var sendFeedbackTrigger = false

    private var canSend: Bool {
        !draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(
                "Ask anything... @files, $skills, /commands",
                text: $draftMessage,
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
    }

    private func dismissKeyboard() {
        isComposerFocused.wrappedValue = false
    }
}

private struct HomeComposerContextRail: View {
    let selectedModelTitle: String
    @Binding var speedMode: HomeComposerSpeedMode
    let availableSpeedModes: [HomeComposerSpeedMode]
    let contextUsage: HomeComposerContextUsage
    let dismissKeyboard: () -> Void

    @State private var isContextUsagePresented = false

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                HomeComposerModelButton(
                    title: selectedModelTitle,
                    dismissKeyboard: dismissKeyboard,
                    action: dismissKeyboard
                )
                .accessibilityLabel("Model, \(selectedModelTitle)")
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                if !availableSpeedModes.isEmpty {
                    HomeComposerMenuChip(
                        title: speedMode.title,
                        systemImage: speedMode.systemImage,
                        displaysTitle: false,
                        displaysChevron: false,
                        isSignal: speedMode == .fast,
                        minWidth: 38,
                        dismissKeyboard: dismissKeyboard
                    ) {
                        Section("Speed") {
                            ForEach(availableSpeedModes) { mode in
                                Button {
                                    dismissKeyboard()
                                    speedMode = mode
                                } label: {
                                    Label(mode.title, systemImage: mode.systemImage)
                                }
                            }
                        }
                    }
                    .accessibilityLabel("Speed, \(speedMode.title)")
                }

                HomeComposerContextUsageButton(
                    usage: contextUsage,
                    isPresented: $isContextUsagePresented,
                    dismissKeyboard: dismissKeyboard
                )
            }
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 4)
        .overlay(alignment: .bottomTrailing) {
            if isContextUsagePresented {
                HomeComposerContextUsagePopover(usage: contextUsage)
                    .offset(x: -2, y: -46)
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .animation(.easeInOut(duration: 0.16), value: isContextUsagePresented)
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
            TapGesture().onEnded {
                dismissKeyboard()
            }
        )
    }
}

private struct HomeComposerContextUsageButton: View {
    let usage: HomeComposerContextUsage
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
        .accessibilityValue("\(usage.usedPercent)% used, \(usage.remainingPercent)% left")
    }
}

private struct HomeComposerContextUsageIndicator: View {
    let usage: HomeComposerContextUsage

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        ZStack {
            Circle()
                .fill(palette.surfaceRaised.opacity(palette.isDark ? 0.42 : 0.72))

            Circle()
                .stroke(palette.accentPrimary.opacity(palette.isDark ? 0.14 : 0.12), lineWidth: 3)
                .frame(width: 23, height: 23)

            Circle()
                .trim(from: 0, to: usage.usedFraction)
                .stroke(
                    palette.accentPrimary.opacity(palette.isDark ? 0.92 : 0.82),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 23, height: 23)

            Text("\(usage.usedPercent)")
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
    let usage: HomeComposerContextUsage

    @Environment(\.sharedPalette) private var palette

    private let cornerRadius: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Context window")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)

                Spacer(minLength: 10)

                Text("\(usage.usedPercent)%")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(palette.accentPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(palette.accentSoft.opacity(palette.isDark ? 0.35 : 1), in: Capsule())
            }

            ProgressView(value: usage.usedFraction)
                .tint(palette.accentPrimary)
                .scaleEffect(x: 1, y: 0.72, anchor: .center)

            HStack(spacing: 10) {
                Text("\(usage.usedPercent)% used")
                    .foregroundStyle(palette.textPrimary)

                Spacer(minLength: 8)

                Text("\(usage.remainingPercent)% left")
                    .foregroundStyle(palette.textTertiary)
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))

            Text("\(usage.usedTokensLabel) / \(usage.tokenLimitLabel) tokens")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(width: 202)
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

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(palette.textSecondary)
            .frame(minWidth: 104)
            .frame(height: 30)
            .padding(.horizontal, 10)
            .homeComposerGlass(cornerRadius: 16, shadowOpacity: 0.06)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture().onEnded {
                dismissKeyboard()
            }
        )
    }
}

#Preview {
    struct PreviewHost: View {
        @State private var draftMessage = ""
        @State private var speedMode = HomeVisualDefaults.speedMode
        @FocusState private var isComposerFocused: Bool

        var body: some View {
            ZStack {
                SharedOpenZonePalette.resolve(.light).surfaceBase.ignoresSafeArea()
                HomeComposerView(
                    draftMessage: $draftMessage,
                    speedMode: $speedMode,
                    selectedModelTitle: HomeVisualDefaults.selectedModelTitle,
                    contextUsage: HomeVisualDefaults.contextUsage,
                    availableSpeedModes: HomeVisualDefaults.availableSpeedModes,
                    isComposerFocused: $isComposerFocused
                )
            }
            .environment(\.sharedPalette, SharedOpenZonePalette.resolve(.light))
        }
    }

    return PreviewHost()
}
