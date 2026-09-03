import Foundation

/// User preferences for automatic context window compaction (Pi-aligned defaults).
nonisolated struct SettingsContextCompactionPreference: Equatable, Sendable, Codable {
    var isEnabled: Bool = true
    /// Legacy field kept for preference migration; no longer used for triggering.
    var triggerThresholdPercent: Int = 90
    var minRecentMessages: Int = 4
    var reserveTokens: Int = 16_384
    var keepRecentTokens: Int = 20_000

    init(
        isEnabled: Bool = true,
        triggerThresholdPercent: Int = 90,
        minRecentMessages: Int = 4,
        reserveTokens: Int = 16_384,
        keepRecentTokens: Int = 20_000
    ) {
        self.isEnabled = isEnabled
        self.triggerThresholdPercent = triggerThresholdPercent
        self.minRecentMessages = minRecentMessages
        self.reserveTokens = reserveTokens
        self.keepRecentTokens = keepRecentTokens
    }
}
