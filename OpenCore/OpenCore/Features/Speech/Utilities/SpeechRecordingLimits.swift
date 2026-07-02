import Foundation

/// Recording duration guardrails aligned with remodex-style voice clips.
nonisolated enum SpeechRecordingLimits: Sendable {
    /// Maximum clip length before auto-stop (seconds).
    static let maxDurationSeconds: TimeInterval = 120

    /// Stops slightly before the hard cap so validation never rejects the clip.
    private static let autoStopLeadTime: TimeInterval = 0.25

    static var autoStopThreshold: TimeInterval {
        max(0, maxDurationSeconds - autoStopLeadTime)
    }

    static func shouldAutoStop(
        elapsed: TimeInterval,
        threshold: TimeInterval = autoStopThreshold
    ) -> Bool {
        elapsed >= threshold
    }
}
