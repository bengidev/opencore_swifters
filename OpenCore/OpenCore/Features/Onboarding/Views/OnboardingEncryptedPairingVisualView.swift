import SwiftUI

/// Encrypted pairing demo — icon row, label row, action button, animated channel.
struct OnboardingEncryptedPairingVisualView: View {
    let isConfirmed: Bool
    let appeared: Bool
    let onToggle: () -> Void

    @Environment(\.sharedPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let centerBoxSize: CGFloat = 82
    private let gapWidth: CGFloat = 14

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            pairingBody(runningPhase: phase)
        }
    }

    @ViewBuilder
    private func pairingBody(runningPhase: TimeInterval) -> some View {
        let pulse = reduceMotion ? 0.5 : (sin((runningPhase.truncatingRemainder(dividingBy: 0.9) / 0.9) * 2 * .pi) + 1) / 2
        let dotScale = isConfirmed && !reduceMotion ? 1 + (0.22 * pulse) : 1
        let dotGlow = isConfirmed && !reduceMotion ? 0.45 + (0.4 * pulse) : 0.45
        let dashPhase = reduceMotion ? 0 : runningPhase.truncatingRemainder(dividingBy: 1.4) / 1.4 * 24
        let shieldScale = isConfirmed ? 1 : 0.94
        let centerAlpha: Double = appeared ? 1 : 0
        let centerScale = appeared ? 1.0 : 0.92

        VStack(spacing: 10) {
            ZStack {
                OnboardingDashedConnectionLine(
                    color: palette.lineSoft.opacity(0.8),
                    dashPhase: dashPhase,
                    animated: isConfirmed
                )
                .padding(.horizontal, OnboardingDeviceNodeIconView.boxWidth / 2)

                HStack(alignment: .center, spacing: 0) {
                    OnboardingDeviceNodeIconView(systemImage: "iphone", active: isConfirmed)
                        .offset(x: appeared ? 0 : -20)
                        .scaleEffect(isConfirmed ? 1 : 0.97)

                    Color.clear.frame(width: gapWidth)

                    centerShieldBox
                        .scaleEffect(shieldScale)

                    Color.clear.frame(width: gapWidth)

                    OnboardingDeviceNodeIconView(systemImage: "macbook", active: true)
                        .offset(x: appeared ? 0 : 20)
                }
                .overlay {
                    Circle()
                        .fill(palette.accentPrimary)
                        .frame(width: 9, height: 9)
                        .shadow(color: palette.accentPrimary.opacity(dotGlow), radius: isConfirmed ? 10 : 6)
                        .scaleEffect(dotScale)
                        .offset(x: dotOffset)
                        .animation(.spring(response: 0.46, dampingFraction: 0.72), value: isConfirmed)
                }
            }
            .frame(height: OnboardingDeviceNodeIconView.boxHeight)
            .opacity(centerAlpha)
            .scaleEffect(centerScale)
            .animation(.spring(response: 0.46, dampingFraction: 0.72), value: appeared)

            HStack {
                OnboardingDeviceNodeLabelsView(title: "LOCAL", subtitle: "Local key")
                    .frame(width: 100, alignment: .center)

                Spacer(minLength: 0)

                OnboardingDeviceNodeLabelsView(title: "OPENCORE", subtitle: "AI chat lane")
                    .frame(width: 100, alignment: .center)
            }
            .padding(.horizontal, 10)
            .opacity(centerAlpha)
            .offset(y: appeared ? 0 : 6)
            .animation(.spring(response: 0.46, dampingFraction: 0.72).delay(0.05), value: appeared)

            pairingActionButton
                .opacity(centerAlpha)
                .offset(y: appeared ? 0 : 8)
                .animation(.spring(response: 0.46, dampingFraction: 0.72).delay(0.08), value: appeared)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var dotOffset: CGFloat {
        let offsetToGapCenter = centerBoxSize / 2 + gapWidth / 2
        return isConfirmed ? offsetToGapCenter : -offsetToGapCenter
    }

    private var centerShieldBox: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(palette.surfaceRaised)
            .frame(width: centerBoxSize, height: centerBoxSize)
            .shadow(
                color: (isConfirmed ? palette.accentPrimary : palette.warning).opacity(isConfirmed ? 0.24 : 0.12),
                radius: isConfirmed ? 6 : 2
            )
            .overlay(
                Image(systemName: isConfirmed ? "lock.shield.fill" : "lock.open.trianglebadge.exclamationmark")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(isConfirmed ? palette.accentPrimary : palette.warning)
                    .padding(14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(palette.lineSoft, lineWidth: 1)
            )
    }

    private var pairingActionButton: some View {
        Button(action: onToggle) {
            HStack(spacing: 7) {
                Image(systemName: isConfirmed ? "arrow.triangle.2.circlepath" : "link.badge.plus")
                Text(isConfirmed ? "ROTATE KEY" : "PAIR DEVICE")
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .monoTracking()
            .foregroundStyle(isConfirmed ? palette.accentPrimary : palette.warning)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill((isConfirmed ? palette.accentPrimary : palette.warning).opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke((isConfirmed ? palette.accentPrimary : palette.warning).opacity(0.32), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isConfirmed ? "Rotate encryption key" : "Pair device")
    }
}

/// Animated dashed connection segment for pairing channel.
private struct OnboardingDashedConnectionLine: View {
    let color: Color
    let dashPhase: Double
    let animated: Bool

    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height / 2))
            path.addLine(to: CGPoint(x: size.width, y: size.height / 2))

            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(
                    lineWidth: 1,
                    dash: [5, 7],
                    dashPhase: animated ? dashPhase : 0
                )
            )
        }
        .frame(height: 3)
    }
}
