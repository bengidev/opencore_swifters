import Foundation

/// Pure display rules for the speech recording indicator — timer, waveform, and voice activity.
nonisolated enum SpeechRecordingDisplayLogic: Sendable {
    static let defaultVoiceActivityThreshold: Float = 0.015
    static let waveformSampleCapacity = 24
    static let defaultBarCount = 16
    private static let idleBarHeight: Float = 0.12
    private static let maxBarHeight: Float = 1.0

    static func formatElapsedDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded(.down)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }

    static func isVoiceActive(
        level: Float,
        threshold: Float = defaultVoiceActivityThreshold
    ) -> Bool {
        level > threshold
    }

    static func normalizedBarHeight(
        level: Float,
        voiceActive: Bool,
        idleHeight: Float = idleBarHeight,
        maxHeight: Float = maxBarHeight
    ) -> Float {
        guard voiceActive else { return idleHeight }
        let scaled = level * 8
        return min(max(scaled, idleHeight), maxHeight)
    }

    static func waveformBarHeights(
        levels: [Float],
        barCount: Int = defaultBarCount,
        threshold: Float = defaultVoiceActivityThreshold
    ) -> [Float] {
        guard barCount > 0 else { return [] }
        guard !levels.isEmpty else {
            return Array(repeating: idleBarHeight, count: barCount)
        }

        var samples = Array(levels.suffix(barCount))
        while samples.count < barCount {
            samples.insert(0, at: 0)
        }
        if samples.count > barCount {
            samples = Array(samples.suffix(barCount))
        }

        return samples.map { level in
            normalizedBarHeight(
                level: level,
                voiceActive: isVoiceActive(level: level, threshold: threshold)
            )
        }
    }

    static func shouldShowRecordingIndicator(isListening: Bool) -> Bool {
        isListening
    }
}
