import Foundation

/// User preferences for automatic context window compaction (Pi-aligned defaults).
nonisolated struct SettingsContextCompactionPreference: Equatable, Sendable, Codable {
    static let thresholdPercentRange = 70...95

    private static let referenceContextLength = 131_072
    private static let tokenStep = 1_024
    private static let legacyDefaultReserveTokens = 16_384
    private static let legacyDefaultKeepRecentTokens = 20_000

    var isEnabled: Bool = true
    /// Context fill level (percent) at which compaction runs.
    var triggerThresholdPercent: Int = 90
    var minRecentMessages: Int = 4
    /// Derived from `triggerThresholdPercent` for trim fallback and planner headroom.
    var reserveTokens: Int = 0
    /// Derived from `triggerThresholdPercent` for planner keep-recent budgeting.
    var keepRecentTokens: Int = 0

    init(
        isEnabled: Bool = true,
        triggerThresholdPercent: Int = 90,
        minRecentMessages: Int = 4,
        reserveTokens: Int? = nil,
        keepRecentTokens: Int? = nil
    ) {
        self.isEnabled = isEnabled
        self.minRecentMessages = minRecentMessages
        self.triggerThresholdPercent = triggerThresholdPercent
        self.reserveTokens = reserveTokens ?? Self.legacyDefaultReserveTokens
        self.keepRecentTokens = keepRecentTokens ?? Self.legacyDefaultKeepRecentTokens
        normalizeAfterDecoding()
    }

    mutating func setThresholdPercent(_ percent: Int, contextLength: Int = referenceContextLength) {
        let clamped = min(Self.thresholdPercentRange.upperBound, max(Self.thresholdPercentRange.lowerBound, percent))
        triggerThresholdPercent = clamped
        reserveTokens = Self.derivedReserveTokens(for: clamped, contextLength: contextLength)
        keepRecentTokens = Self.derivedKeepRecentTokens(for: clamped, contextLength: contextLength)
    }

    /// Reconciles decoded fields and migrates legacy reserve-token preferences.
    mutating func normalizeAfterDecoding() {
        let derivedReserve = Self.derivedReserveTokens(
            for: triggerThresholdPercent,
            contextLength: Self.referenceContextLength
        )
        let derivedKeep = Self.derivedKeepRecentTokens(
            for: triggerThresholdPercent,
            contextLength: Self.referenceContextLength
        )

        let matchesDerived = reserveTokens == derivedReserve && keepRecentTokens == derivedKeep
        let looksLikeLegacyDefaults = reserveTokens == Self.legacyDefaultReserveTokens
            && keepRecentTokens == Self.legacyDefaultKeepRecentTokens

        if matchesDerived {
            return
        }

        if looksLikeLegacyDefaults {
            setThresholdPercent(triggerThresholdPercent)
            return
        }

        let migratedPercent = Self.thresholdPercent(
            reserveTokens: reserveTokens,
            contextLength: Self.referenceContextLength
        )
        setThresholdPercent(migratedPercent)
    }

    func scaledReserveTokens(for contextLength: Int) -> Int {
        Self.derivedReserveTokens(for: triggerThresholdPercent, contextLength: contextLength)
    }

    func scaledKeepRecentTokens(for contextLength: Int) -> Int {
        Self.derivedKeepRecentTokens(for: triggerThresholdPercent, contextLength: contextLength)
    }

    static func derivedReserveTokens(
        for percent: Int,
        contextLength: Int = referenceContextLength
    ) -> Int {
        guard contextLength > 0 else { return 4_096 }
        let reservedFraction = Double(100 - percent) / 100.0
        let raw = Double(contextLength) * reservedFraction
        return snapTokenCount(Int(raw.rounded()), range: 4_096...32_768)
    }

    static func derivedKeepRecentTokens(
        for percent: Int,
        contextLength: Int = referenceContextLength
    ) -> Int {
        let raw = Double(derivedReserveTokens(for: percent, contextLength: contextLength)) * 1.5
        return snapTokenCount(Int(raw.rounded()), range: 4_096...40_960)
    }

    static func thresholdPercent(reserveTokens: Int, contextLength: Int) -> Int {
        guard contextLength > 0 else { return 90 }
        let raw = 100 - Int((Double(reserveTokens) / Double(contextLength) * 100).rounded())
        return min(thresholdPercentRange.upperBound, max(thresholdPercentRange.lowerBound, raw))
    }

    private static func snapTokenCount(_ value: Int, range: ClosedRange<Int>) -> Int {
        let stepped = max(range.lowerBound, ((value + tokenStep / 2) / tokenStep) * tokenStep)
        return min(range.upperBound, stepped)
    }
}
