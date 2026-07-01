import SwiftUI

/// Full-width recording composer — replaces the text field while speech mode is active.
struct SpeechRecordingComposerView: View {
    let elapsedDuration: TimeInterval
    let audioLevels: [Float]
    let isVoiceActive: Bool
    let isTranscribing: Bool
    let onCancel: () -> Void

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            recordingIndicator

            GeometryReader { geometry in
                SpeechComposerWaveformView(
                    heights: SpeechRecordingDisplayLogic.waveformBarHeights(
                        levels: audioLevels,
                        barCount: SpeechRecordingDisplayLogic.composerBarCount(
                            forWidth: geometry.size.width
                        )
                    ),
                    activeColor: palette.accentPrimary,
                    idleColor: palette.textTertiary.opacity(0.4)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .frame(height: 28)

            Text(SpeechRecordingDisplayLogic.formatElapsedDuration(elapsedDuration))
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.textSecondary)
                .monospacedDigit()
                .accessibilityLabel("Recording duration")
                .accessibilityValue(SpeechRecordingDisplayLogic.formatElapsedDuration(elapsedDuration))

            if isTranscribing {
                ProgressView()
                    .controlSize(.small)
                    .tint(palette.accentPrimary)
                    .accessibilityLabel("Transcribing voice")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(minHeight: 56)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(palette.surfaceSubtle.opacity(palette.isDark ? 0.45 : 0.65))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(palette.textTertiary.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isTranscribing ? "Transcribing voice" : "Voice recording in progress")
    }

    private var recordingIndicator: some View {
        Circle()
            .fill(isTranscribing ? palette.textTertiary.opacity(0.5) : (isVoiceActive ? palette.accentPrimary : palette.textTertiary.opacity(0.7)))
            .frame(width: 8, height: 8)
            .overlay {
                if isTranscribing {
                    Circle()
                        .stroke(palette.accentPrimary.opacity(0.35), lineWidth: 2)
                        .frame(width: 14, height: 14)
                }
            }
            .animation(.easeOut(duration: 0.12), value: isVoiceActive)
    }
}

private struct SpeechComposerWaveformView: View {
    let heights: [Float]
    let activeColor: Color
    let idleColor: Color

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(heights.enumerated()), id: \.offset) { _, height in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(height > 0.12 ? activeColor : idleColor)
                    .frame(width: 2.5, height: max(4, CGFloat(height) * 28))
                    .animation(.easeOut(duration: 0.08), value: height)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        SpeechRecordingComposerView(
            elapsedDuration: 42,
            audioLevels: [0.02, 0.08, 0.2, 0.15, 0.05, 0.12],
            isVoiceActive: true,
            isTranscribing: false,
            onCancel: {}
        )

        SpeechRecordingComposerView(
            elapsedDuration: 12,
            audioLevels: [0.05, 0.1, 0.08],
            isVoiceActive: false,
            isTranscribing: true,
            onCancel: {}
        )
    }
    .padding()
    .environment(\.sharedPalette, SharedOpenCorePalette.resolve(.light))
}
