import SwiftUI
import ThinkingOrbsKit

/// Left/right chat bubble for onboarding — user prompts on the right, thinking orbs
/// and feature replies on the left.
struct OnboardingChatBubbleView: View {
    let message: OnboardingChatMessage

    @Environment(\.sharedPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var bubbleNamespace

    private let cornerRadius: CGFloat = 20
    private let oppositeSpacerMinWidth: CGFloat = 52
    private let maxBubbleWidth: CGFloat = 280
    private let thinkingOrbDisplaySize: CGFloat = 34

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.role == .user {
                Spacer(minLength: oppositeSpacerMinWidth)
                userBubble
            } else {
                leftAlignedBubble
                Spacer(minLength: oppositeSpacerMinWidth)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
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
    }

    // MARK: - Assistant / Thinking (left)

    @ViewBuilder
    private var leftAlignedBubble: some View {
        Group {
            if message.role == .thinking {
                thinkingBubble
                    .matchedGeometryEffect(id: "bubble-shell-\(message.id)", in: bubbleNamespace)
            } else {
                assistantBubble
                    .matchedGeometryEffect(id: "bubble-shell-\(message.id)", in: bubbleNamespace)
            }
        }
        .animation(
            reduceMotion
                ? .easeOut(duration: 0.2)
                : .spring(response: 0.58, dampingFraction: 0.82),
            value: message.role
        )
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
        .transition(
            .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .opacity
            )
        )
    }

    private var assistantBubble: some View {
        HStack(alignment: .top, spacing: 12) {
            featureOrb

            VStack(alignment: .leading, spacing: 3) {
                Text(message.feature?.title ?? "")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)

                Text(message.feature?.subtitle ?? "")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(bubbleBackground)
        .overlay(bubbleStroke)
        .frame(maxWidth: maxBubbleWidth, alignment: .leading)
        .transition(
            .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .leading)),
                removal: .opacity
            )
        )
    }

    private var bubbleBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(palette.surfacePaper.opacity(palette.isDark ? 0.92 : 1))
    }

    private var bubbleStroke: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(palette.lineSoft, lineWidth: 1)
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
        OnboardingChatMessage(id: UUID(), role: .assistant, feature: feature, text: feature.subtitle)
    }

    func morphToAssistant() -> OnboardingChatMessage {
        guard let feature else { return self }
        return OnboardingChatMessage(id: id, role: .assistant, feature: feature, text: feature.subtitle)
    }
}

private extension OnboardingFeature {
    var thinkingOrbState: OrbState {
        let states: [OrbState] = [.breathing, .composing, .shaping, .working]
        return states[orbStyleIndex % states.count]
    }
}
