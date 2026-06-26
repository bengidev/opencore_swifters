import Foundation

/// User preferences for automatic context window compaction.
nonisolated struct SettingsContextCompactionPreference: Equatable, Sendable, Codable {
    var isEnabled: Bool = false
    var triggerThresholdPercent: Int = 90
    var minRecentMessages: Int = 4

    init(
        isEnabled: Bool = false,
        triggerThresholdPercent: Int = 90,
        minRecentMessages: Int = 4
    ) {
        self.isEnabled = isEnabled
        self.triggerThresholdPercent = triggerThresholdPercent
        self.minRecentMessages = minRecentMessages
    }
}
