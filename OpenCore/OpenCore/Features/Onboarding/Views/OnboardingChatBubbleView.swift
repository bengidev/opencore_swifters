import SwiftUI
import ThinkingOrbsKit

/// Left/right chat bubble for onboarding — user prompts on the right, thinking orbs
/// and feature replies on the left.
struct OnboardingChatBubbleView: View {
    let message: OnboardingChatMessage
    let containerWidth: CGFloat
    var animatesAppearance: Bool = true

    @Environment(\.sharedPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cornerRadius: CGFloat = 20
    private let oppositeSpacerMinWidth: CGFloat = 52
    private let maxBubbleWidthRatio: CGFloat = 0.8
    private let thinkingOrbDisplaySize: CGFloat = 34

    private var maxBubbleWidth: CGFloat {
        containerWidth * maxBubbleWidthRatio
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.role == .user {
                Spacer(minLength: oppositeSpacerMinWidth)
                userBubble
                    .modifier(
                        OnboardingChatBubbleReveal(
                            anchor: .bottomTrailing,
                            isEnabled: animatesAppearance && !reduceMotion
                        )
                    )
            } else {
                leftAlignedBubble
                    .animation(OnboardingChatFeedTiming.placement, value: message.role)
                    .modifier(
                        OnboardingChatBubbleReveal(
                            anchor: .bottomLeading,
                            isEnabled: animatesAppearance && !reduceMotion
                        )
                    )
                Spacer(minLength: oppositeSpacerMinWidth)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    // MARK: - User (right)

    private var userBubble: some View {
        Text(message.text)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(palette.controlStrongText)
            .multilineTextAlignment(.trailing)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(palette.controlStrong)
            )
            .frame(maxWidth: maxBubbleWidth, alignment: .trailing)
            .accessibilityLabel(message.text)
    }

    // MARK: - Assistant / Thinking (left)

    /// Thinking and assistant are separate layouts. Role changes crossfade in place
    /// under the placement ease; the reveal modifier does not replay, so the taller
    /// reply cannot travel through the user bubble above it.
    @ViewBuilder
    private var leftAlignedBubble: some View {
        switch message.role {
        case .thinking:
            thinkingBubble
                .transition(.opacity)
        case .assistant:
            assistantBubble
                .transition(.opacity)
        case .user:
            EmptyView()
        }
    }

    private var thinkingBubble: some View {
        HStack(alignment: .center, spacing: 10) {
            ThinkingOrb(
                state: message.feature?.thinkingOrbState ?? .breathing,
                size: .px64,
                theme: palette.isDark ? .dark : .light,
                displaySize: thinkingOrbDisplaySize
            )
            .frame(width: thinkingOrbDisplaySize, height: thinkingOrbDisplaySize)

            Text("Thinking…")
                .font(.system(size: 14, weight: .medium))
                .shimmeringText(baseColor: palette.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(bubbleBackground)
        .overlay(bubbleStroke)
        .frame(maxWidth: maxBubbleWidth, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Thinking")
    }

    private var assistantBubble: some View {
        HStack(alignment: .top, spacing: 12) {
            featureOrb

            VStack(alignment: .leading, spacing: 6) {
                Text(message.feature?.title ?? "")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)

                Text(message.feature?.subtitle ?? "")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let description = message.feature?.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(palette.textSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(bubbleBackground)
        .overlay(bubbleStroke)
        .frame(maxWidth: maxBubbleWidth, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(assistantAccessibilityLabel)
    }

    private var bubbleBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(palette.surfacePaper.opacity(palette.isDark ? 0.92 : 1))
    }

    private var bubbleStroke: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(palette.lineSoft, lineWidth: 1)
    }

    private var assistantAccessibilityLabel: String {
        guard let feature = message.feature else { return message.text }
        return feature.feedAccessibilityLabel
    }

    private var featureOrb: some View {
        let feature = message.feature
        let orbColors = feature?.orbColors(palette: palette) ?? [palette.textTertiary]
        let iconColor = palette.isDark ? palette.surfaceBase : palette.controlStrongText

        return ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        colors: orbColors + [orbColors[0]],
                        center: .center
                    )
                )
                .blur(radius: palette.isDark ? 5 : 3)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            (palette.isDark ? Color.white : palette.controlStrongText)
                                .opacity(palette.isDark ? 0.5 : 0.32),
                            .clear
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 18
                    )
                )

            Image(systemName: feature?.iconName ?? "sparkle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())
        .overlay(
            Circle()
                .strokeBorder(palette.lineSoft.opacity(0.7), lineWidth: 1)
        )
    }
}

// Fade and a small scale from the bubble corner after the feed has eased the
// new slot open, so the bubble does not draw through the one above it.
private struct OnboardingChatBubbleReveal: ViewModifier {
    enum Anchor {
        case bottomLeading
        case bottomTrailing
    }

    let anchor: Anchor
    let isEnabled: Bool

    @State private var hasRevealed: Bool
    @State private var revealTask: Task<Void, Never>?

    init(anchor: Anchor, isEnabled: Bool) {
        self.anchor = anchor
        self.isEnabled = isEnabled
        _hasRevealed = State(initialValue: !isEnabled)
    }

    private var unitAnchor: UnitPoint {
        switch anchor {
        case .bottomLeading:
            return .bottomLeading
        case .bottomTrailing:
            return .bottomTrailing
        }
    }

    private var isConcealed: Bool {
        isEnabled && !hasRevealed
    }

    func body(content: Content) -> some View {
        content
            .opacity(isConcealed ? 0 : 1)
            .scaleEffect(isConcealed ? 0.96 : 1, anchor: unitAnchor)
            .onAppear {
                scheduleReveal()
            }
            .onDisappear {
                revealTask?.cancel()
                revealTask = nil
            }
    }

    private func scheduleReveal() {
        guard isEnabled else {
            hasRevealed = true
            return
        }
        guard !hasRevealed else { return }

        revealTask?.cancel()
        revealTask = Task { @MainActor in
            // Stay hidden until the feed has eased the new slot open, then fade in
            // place. Fading during that ease draws the bubble through the one above it.
            try? await Task.sleep(for: OnboardingChatFeedTiming.revealDelay)
            guard !Task.isCancelled, !hasRevealed else { return }
            withAnimation(OnboardingChatFeedTiming.reveal) {
                hasRevealed = true
            }
        }
    }
}

enum OnboardingChatRole: Equatable {
    case user
    case thinking
    case assistant
}

struct OnboardingChatMessage: Identifiable {
    let id: UUID
    let role: OnboardingChatRole
    let feature: OnboardingFeature?
    let text: String

    static func user(prompt: String, feature: OnboardingFeature) -> OnboardingChatMessage {
        OnboardingChatMessage(id: UUID(), role: .user, feature: feature, text: prompt)
    }

    static func thinking(feature: OnboardingFeature) -> OnboardingChatMessage {
        OnboardingChatMessage(id: UUID(), role: .thinking, feature: feature, text: "Thinking…")
    }

    static func assistant(feature: OnboardingFeature) -> OnboardingChatMessage {
        OnboardingChatMessage(id: UUID(), role: .assistant, feature: feature, text: feature.accessibilitySummary)
    }

    func morphToAssistant() -> OnboardingChatMessage {
        guard let feature else { return self }
        return OnboardingChatMessage(id: id, role: .assistant, feature: feature, text: feature.accessibilitySummary)
    }
}

private extension OnboardingFeature {
    var thinkingOrbState: OrbState {
        let states: [OrbState] = [.breathing, .composing, .shaping, .working]
        return states[orbStyleIndex % states.count]
    }
}
