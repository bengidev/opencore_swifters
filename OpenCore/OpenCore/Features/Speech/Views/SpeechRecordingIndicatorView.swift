import SwiftUI

/// Top recording bar — status dot, live waveform, timer, and cancel action.
struct SpeechRecordingIndicatorView: View {
    let elapsedDuration: TimeInterval
    let audioLevels: [Float]
    let isVoiceActive: Bool
    let onCancel: () -> Void

    @Environment(\.sharedPalette) private var palette

    private let barCount = SpeechRecordingDisplayLogic.defaultBarCount

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isVoiceActive ? palette.accentPrimary : palette.textTertiary.opacity(0.7))
                .frame(width: 8, height: 8)
                .animation(.easeOut(duration: 0.12), value: isVoiceActive)

            SpeechWaveformBarsView(
                heights: SpeechRecordingDisplayLogic.waveformBarHeights(
                    levels: audioLevels,
                    barCount: barCount
                ),
                activeColor: palette.accentPrimary,
                idleColor: palette.textTertiary.opacity(0.45)
            )
            .frame(height: 22)
            .accessibilityHidden(true)

            Text(SpeechRecordingDisplayLogic.formatElapsedDuration(elapsedDuration))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.textSecondary)
                .monospacedDigit()
                .accessibilityLabel("Recording duration")
                .accessibilityValue(SpeechRecordingDisplayLogic.formatElapsedDuration(elapsedDuration))

            Spacer(minLength: 4)

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
                    .frame(width: 28, height: 28)
                    .background {
                        Circle()
                            .fill(palette.surfaceSubtle.opacity(palette.isDark ? 0.55 : 0.85))
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel voice input")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.surfaceSubtle.opacity(palette.isDark ? 0.35 : 0.55))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Voice recording in progress")
    }
}

private struct SpeechWaveformBarsView: View {
    let heights: [Float]
    let activeColor: Color
    let idleColor: Color

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(heights.enumerated()), id: \.offset) { _, height in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(height > 0.12 ? activeColor : idleColor)
                    .frame(width: 2.5, height: max(4, CGFloat(height) * 22))
                    .animation(.easeOut(duration: 0.08), value: height)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        SpeechRecordingIndicatorView(
            elapsedDuration: 9,
            audioLevels: [0.02, 0.05, 0.12, 0.08, 0.03],
            isVoiceActive: true,
            onCancel: {}
        )

        SpeechRecordingIndicatorView(
            elapsedDuration: 2,
            audioLevels: [],
            isVoiceActive: false,
            onCancel: {}
        )
    }
    .padding()
    .environment(\.sharedPalette, SharedOpenCorePalette.resolve(.light))
}
