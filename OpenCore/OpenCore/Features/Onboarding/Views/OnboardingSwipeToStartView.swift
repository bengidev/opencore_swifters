import SwiftUI
import UIKit

/// Swipe-to-unlock CTA — knob must reach the trailing edge; otherwise springs back with haptic feedback.
struct OnboardingSwipeToStartView: View {
    @Binding var isUnlocked: Bool
    var onComplete: () async -> Bool

    @Environment(\.sharedPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var isCompleting = false

    private let trackHeight: CGFloat = 58
    private let knobSize: CGFloat = 46
    private let innerInset: CGFloat = 6
    /// Knob must reach this fraction of the track before unlocking.
    private let trailingUnlockThreshold: CGFloat = 0.92

    var body: some View {
        GeometryReader { proxy in
            let maxDrag = max(proxy.size.width - knobSize - (innerInset * 2), 1)
            let labelOpacity = 1 - Double(dragOffset / maxDrag)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(palette.surfaceSubtle)
                    .overlay(
                        Capsule()
                            .strokeBorder(palette.lineSoft, lineWidth: 1)
                    )

                HStack {
                    Spacer()
                    Text("swipe to get started")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .monoTracking()
                        .shimmeringText(
                            baseColor: palette.textTertiary,
                            isActive: !isUnlocked && labelOpacity > 0.15
                        )
                        .opacity(labelOpacity)
                    Spacer()
                }

                Circle()
                    .fill(palette.controlStrong)
                    .frame(width: knobSize, height: knobSize)
                    .overlay(
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(palette.controlStrongText)
                    )
                    .scaleEffect(isDragging ? 0.97 : 1)
                    .offset(x: innerInset + dragOffset)
                    .animation(
                        reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.22, dampingFraction: 0.72),
                        value: isDragging
                    )
                    .gesture(dragGesture(maxDrag: maxDrag))
            }
        }
        .frame(height: trackHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Swipe to get started")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            Task {
                await attemptUnlock(maxDrag: nil)
            }
        }
    }

    private func dragGesture(maxDrag: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard !isUnlocked, !isCompleting else { return }

                if !isDragging {
                    isDragging = true
                    prepareHaptics()
                    UISelectionFeedbackGenerator().selectionChanged()
                }

                dragOffset = min(max(0, value.translation.width), maxDrag)
            }
            .onEnded { _ in
                guard !isUnlocked, !isCompleting else { return }
                isDragging = false

                let reachedTrailing = dragOffset >= maxDrag * trailingUnlockThreshold

                if reachedTrailing {
                    Task {
                        await attemptUnlock(maxDrag: maxDrag)
                    }
                } else {
                    withAnimation(reboundAnimation) {
                        dragOffset = 0
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
    }

    @MainActor
    private func attemptUnlock(maxDrag: CGFloat?) async {
        guard !isUnlocked, !isCompleting else { return }
        isCompleting = true

        if let maxDrag {
            withAnimation(unlockAnimation) {
                dragOffset = maxDrag
            }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let succeeded = await onComplete()

        if succeeded {
            isUnlocked = true
        } else {
            withAnimation(reboundAnimation) {
                dragOffset = 0
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        isCompleting = false
    }

    private func prepareHaptics() {
        UIImpactFeedbackGenerator(style: .light).prepare()
        UIImpactFeedbackGenerator(style: .medium).prepare()
        UISelectionFeedbackGenerator().prepare()
    }

    private var unlockAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.2)
            : .spring(response: 0.35, dampingFraction: 0.72)
    }

    private var reboundAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.18)
            : .spring(response: 0.42, dampingFraction: 0.68)
    }
}
