import Foundation

/// Pure display rules for in-chat voice-note playback — timer and waveform progress.
nonisolated enum ChatVoiceNotePlaybackDisplayLogic: Sendable {
    static func playbackProgress(
        currentTime: TimeInterval,
        duration: TimeInterval
    ) -> Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }

    static func displayedDuration(
        currentTime: TimeInterval,
        totalDuration: TimeInterval,
        isPlaybackActive: Bool
    ) -> TimeInterval {
        isPlaybackActive ? currentTime : totalDuration
    }

    static func isBarPlayed(
        barIndex: Int,
        barCount: Int,
        progress: Double
    ) -> Bool {
        guard barCount > 0, barIndex >= 0, barIndex < barCount else { return false }
        let barEndProgress = Double(barIndex + 1) / Double(barCount)
        return barEndProgress <= progress
    }
}
