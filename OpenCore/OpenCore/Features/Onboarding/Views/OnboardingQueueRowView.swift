import SwiftUI

/// Queue row — status indicator, title, detail, action icon with running pulse.
struct OnboardingQueueRowView: View {
    let item: OnboardingQueueItem
    let index: Int
    let isLast: Bool
    var rowEnterDelayMs: UInt64 = 0

    @Environment(\.sharedPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var contentOpacity: Double = 0
    @State private var contentOffset: CGFloat = 14

    private var isRunning: Bool { item.status == .running }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            rowBody(runningPhase: phase)
        }
        .task(id: "\(item.id)-\(rowEnterDelayMs)") {
            await runEntrance()
        }
    }

    @ViewBuilder
    private func rowBody(runningPhase: TimeInterval) -> some View {
        let pulse = oscillation(phase: runningPhase, period: 0.72)
        let cardPulse = oscillation(phase: runningPhase, period: 1.1)
        let connectorProgress = linearPhase(phase: runningPhase, period: 0.9)
        let hourglassRotation = linearPhase(phase: runningPhase, period: 1.6) * 180

        let dotScale = isRunning && !reduceMotion ? 1 + (0.35 * pulse) : 1
        let dotAlpha = isRunning && !reduceMotion ? 0.45 + (0.55 * pulse) : 1
        let cardFillAlpha: Double = {
            if isRunning && !reduceMotion { return 0.5 + (0.12 * cardPulse) }
            return index == 0 ? 0.5 : 0.3
        }()
        let borderColor = borderColor(isRunning: isRunning, pulse: pulse)

        HStack(spacing: 10) {
            VStack(spacing: 3) {
                Circle()
                    .fill(statusColor.opacity(dotAlpha))
                    .frame(width: 8, height: 8)
                    .scaleEffect(dotScale)

                if !isLast {
                    ZStack(alignment: .top) {
                        Rectangle()
                            .fill(palette.lineSoft.opacity(0.72))
                            .frame(width: 1, height: 20)

                        if isRunning && !reduceMotion {
                            Rectangle()
                                .fill(palette.accentPrimary.opacity(0.55))
                                .frame(width: 1, height: 20 * connectorProgress)
                        }
                    }
                }
            }
            .frame(width: 12)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(item.status.rawValue)
                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                        .tracking(-0.24)
                        .foregroundStyle(statusColor)
                    Text(item.title)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Text(item.detail)
                    .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(palette.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }

            Spacer(minLength: 4)

            Image(systemName: isRunning ? "hourglass" : "text.line.first.and.arrowtriangle.forward")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isRunning ? palette.accentPrimary : palette.textTertiary)
                .rotationEffect(.degrees(isRunning && !reduceMotion ? hourglassRotation : 0))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(palette.surfaceSubtle.opacity(cardFillAlpha))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .opacity(contentOpacity)
        .offset(y: contentOffset)
    }

    private var statusColor: Color {
        switch item.status {
        case .running: palette.accentPrimary
        case .next: palette.warning
        case .queued: palette.textSecondary
        case .ready: palette.success
        }
    }

    private func borderColor(isRunning: Bool, pulse: Double) -> Color {
        if isRunning {
            palette.accentPrimary.opacity(0.28 + (0.12 * pulse))
        } else if index == 0 {
            palette.accentPrimary.opacity(0.34)
        } else {
            palette.lineSoft
        }
    }

    private func oscillation(phase: TimeInterval, period: TimeInterval) -> Double {
        let progress = linearPhase(phase: phase, period: period)
        return (sin(progress * 2 * .pi) + 1) / 2
    }

    private func linearPhase(phase: TimeInterval, period: TimeInterval) -> Double {
        guard period > 0 else { return 0 }
        return phase.truncatingRemainder(dividingBy: period) / period
    }

    @MainActor
    private func runEntrance() async {
        contentOpacity = 0
        contentOffset = 14

        if reduceMotion {
            contentOpacity = 1
            contentOffset = 0
            return
        }

        if rowEnterDelayMs > 0 {
            try? await Task.sleep(nanoseconds: rowEnterDelayMs * 1_000_000)
        }

        withAnimation(.spring(response: 0.52, dampingFraction: 0.86)) {
            contentOpacity = 1
            contentOffset = 0
        }
    }
}
