import SwiftUI

struct ChatWaveformBarsView: View {
    let heights: [Float]
    var progress: Double = 0
    var showsPlaybackProgress = false
    let activeColor: Color
    let idleColor: Color
    var unplayedColor: Color?

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(heights.enumerated()), id: \.offset) { index, height in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(barColor(for: index, height: height))
                    .frame(width: 3, height: max(4, CGFloat(height) * barHeightScale))
                    .animation(showsPlaybackProgress ? .easeOut(duration: 0.08) : nil, value: progress)
            }
        }
    }

    private var barHeightScale: CGFloat {
        showsPlaybackProgress ? 24 : 22
    }

    private func barColor(for index: Int, height: Float) -> Color {
        let baseColor = height > 0.12 ? activeColor : idleColor
        guard showsPlaybackProgress else { return baseColor }

        let played = ChatVoiceNotePlaybackDisplayLogic.isBarPlayed(
            barIndex: index,
            barCount: heights.count,
            progress: progress
        )
        if played {
            return baseColor
        }
        return unplayedColor ?? idleColor
    }
}
