import Foundation

/// Result of a compaction pass: projected model context plus optional append-only checkpoint.
nonisolated struct SettingsContextCompactionOutcome: Equatable, Sendable {
    let projectedMessages: [ChatMessage]
    let checkpoint: AtomCompactionCheckpoint?

    static func unchanged(_ messages: [ChatMessage]) -> SettingsContextCompactionOutcome {
        SettingsContextCompactionOutcome(projectedMessages: messages, checkpoint: nil)
    }
}
