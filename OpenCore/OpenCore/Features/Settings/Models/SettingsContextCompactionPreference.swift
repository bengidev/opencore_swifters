import Foundation

/// User preferences for automatic context window compaction (Pi-aligned defaults).
nonisolated struct SettingsContextCompactionPreference: Equatable, Sendable, Codable {
    static let thresholdPercentRange = 70...95

    var isEnabled: Bool = true
    /// Context fill level (percent) at which compaction runs.
    var triggerThresholdPercent: Int = 90
    var minRecentMessages: Int = 4
    /// Derived from `triggerThresholdPercent` for trim fallback and planner headroom.
    var reserveTokens: Int = 16_384
    /// Derived from `triggerThresholdPercent` for planner keep-recent budgeting.
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

    mutating func setThresholdPercent(_ percent: Int) {
        let clamped = min(Self.thresholdPercentRange.upperBound, max(Self.thresholdPercentRange.lowerBound, percent))
        triggerThresholdPercent = clamped
        reserveTokens = Self.derivedReserveTokens(for: clamped)
        keepRecentTokens = Self.derivedKeepRecentTokens(for: clamped)
    }

    static func derivedReserveTokens(for percent: Int) -> Int {
        let reservedFraction = Double(100 - percent) / 100.0
        let raw = Double(referenceContextLength) * reservedFraction
        return snapTokenCount(Int(raw.rounded()), range: 4_096...32_768)
    }

    static func derivedKeepRecentTokens(for percent: Int) -> Int {
        let raw = Double(derivedReserveTokens(for: percent)) * 1.5
        return snapTokenCount(Int(raw.rounded()), range: 4_096...40_960)
    }

    private static let referenceContextLength = 131_072
    private static let tokenStep = 1_024

    private static func snapTokenCount(_ value: Int, range: ClosedRange<Int>) -> Int {
        let stepped = max(range.lowerBound, ((value + tokenStep / 2) / tokenStep) * tokenStep)
        return min(range.upperBound, stepped)
    }
}
