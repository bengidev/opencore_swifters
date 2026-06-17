import SwiftUI

/// Prompt queue demo — staggered rows, running pulse, animated timeline.
struct OnboardingPromptQueueVisualView: View {
    let queuedPromptCount: Int
    let appeared: Bool

    private var visibleCount: Int {
        min(max(queuedPromptCount, 1), OnboardingQueueItem.samples.count)
    }

    var body: some View {
        VStack(spacing: 9) {
            ForEach(Array(OnboardingQueueItem.samples.enumerated()), id: \.element.id) { index, item in
                if appeared && index < visibleCount {
                    OnboardingQueueRowView(
                        item: item,
                        index: index,
                        isLast: index == visibleCount - 1,
                        rowEnterDelayMs: UInt64(index) * 72
                    )
                    .transition(
                        .asymmetric(
                            insertion: .opacity
                                .combined(with: .move(edge: .bottom))
                                .combined(with: .scale(scale: 0.94, anchor: .top)),
                            removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .top))
                        )
                    )
                }
            }

            Color.clear
                .frame(height: 16)
                .id("queueLast")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .animation(.easeOut(duration: 0.46), value: visibleCount)
        .animation(.easeOut(duration: 0.42), value: appeared)
    }
}
