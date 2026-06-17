import SwiftUI

/// Encrypted pairing demo — icon row, label row, then action button (no overlapping layers).
struct OnboardingEncryptedPairingVisualView: View {
    let isConfirmed: Bool
    let appeared: Bool
    let onToggle: () -> Void

    @Environment(\.sharedPalette) private var palette

    private let centerBoxSize: CGFloat = 82
    private let deviceBoxWidth = OnboardingDeviceNodeIconView.boxWidth
    private let gapWidth: CGFloat = 14

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Capsule(style: .continuous)
                    .stroke(palette.lineSoft.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [5, 7]))
                    .frame(height: 3)
                    .padding(.horizontal, deviceBoxWidth / 2)

                HStack(alignment: .center, spacing: 0) {
                    OnboardingDeviceNodeIconView(systemImage: "iphone", active: isConfirmed)
                        .offset(x: appeared ? 0 : -20)

                    connectionGap

                    centerShieldBox

                    connectionGap

                    OnboardingDeviceNodeIconView(systemImage: "macbook", active: true)
                        .offset(x: appeared ? 0 : 20)
                }
                .overlay {
                    travelingDot
                }
            }
            .frame(height: OnboardingDeviceNodeIconView.boxHeight)

            HStack {
                OnboardingDeviceNodeLabelsView(title: "LOCAL", subtitle: "Local key")
                    .frame(width: 100, alignment: .center)

                Spacer(minLength: 0)

                OnboardingDeviceNodeLabelsView(title: "OPENCORE", subtitle: "AI chat lane")
                    .frame(width: 100, alignment: .center)
            }
            .padding(.horizontal, 10)

            pairingActionButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var connectionGap: some View {
        Color.clear
            .frame(width: gapWidth)
    }

    private var travelingDot: some View {
        Circle()
            .fill(palette.accentPrimary)
            .frame(width: 9, height: 9)
            .shadow(color: palette.accentPrimary.opacity(0.45), radius: 10)
            .offset(x: dotOffset)
            .animation(.spring(response: 0.46, dampingFraction: 0.72), value: isConfirmed)
    }

    /// Horizontal offset from center so the dot sits in the gap between boxes.
    private var dotOffset: CGFloat {
        let offsetToGapCenter = centerBoxSize / 2 + gapWidth / 2
        return isConfirmed ? offsetToGapCenter : -offsetToGapCenter
    }

    private var centerShieldBox: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(palette.surfaceRaised)
            .frame(width: centerBoxSize, height: centerBoxSize)
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
