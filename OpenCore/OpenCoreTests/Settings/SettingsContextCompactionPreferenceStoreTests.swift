import Foundation
import Testing

@testable import OpenCore

@Suite("Settings Context Compaction Preference Store")
struct SettingsContextCompactionPreferenceStoreTests {
    @Test("Default preference uses 90 percent threshold")
    func defaultThresholdIsNinety() {
        let store = SettingsInMemoryContextCompactionPreferenceStore()
        let preference = store.preference()
        #expect(preference.triggerThresholdPercent == 90)
        #expect(preference.isEnabled == true)
        #expect(preference.reserveTokens == SettingsContextCompactionPreference.derivedReserveTokens(for: 90))
        #expect(preference.keepRecentTokens == SettingsContextCompactionPreference.derivedKeepRecentTokens(for: 90))
    }

    @Test("UserDefaults store round-trips preference")
    func userDefaultsRoundTrip() {
        let suite = "SettingsContextCompactionPreferenceStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let store = SettingsUserDefaultsContextCompactionPreferenceStore(suiteName: suite)
        var preference = store.preference()
        preference.isEnabled = false
        preference.setThresholdPercent(75)
        store.setPreference(preference)

        let reloaded = SettingsUserDefaultsContextCompactionPreferenceStore(suiteName: suite)
        #expect(reloaded.preference().isEnabled == false)
        #expect(reloaded.preference().triggerThresholdPercent == 75)
        #expect(reloaded.preference().reserveTokens == SettingsContextCompactionPreference.derivedReserveTokens(for: 75))
    }

    @Test("Legacy reserve tokens migrate to threshold percent on load")
    func legacyReserveTokensMigrateOnLoad() throws {
        let suite = "SettingsContextCompactionPreferenceStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let legacyReserveTokens = 4_096
        let referenceContextLength = 131_072
        struct LegacyPayload: Codable {
            var isEnabled = true
            var triggerThresholdPercent = 90
            var minRecentMessages = 4
            var reserveTokens: Int
            var keepRecentTokens = 20_000

            init(reserveTokens: Int) {
                self.reserveTokens = reserveTokens
            }
        }
        let data = try JSONEncoder().encode(LegacyPayload(reserveTokens: legacyReserveTokens))
        defaults.set(data, forKey: "opencore.context.compaction.v1")

        let store = SettingsUserDefaultsContextCompactionPreferenceStore(suiteName: suite)
        let migrated = store.preference()
        let expectedPercent = SettingsContextCompactionPreference.thresholdPercent(
            reserveTokens: legacyReserveTokens,
            contextLength: referenceContextLength
        )
        #expect(migrated.triggerThresholdPercent == expectedPercent)
        #expect(
            migrated.reserveTokens
                == SettingsContextCompactionPreference.derivedReserveTokens(for: expectedPercent)
        )
        #expect(
            migrated.keepRecentTokens
                == SettingsContextCompactionPreference.derivedKeepRecentTokens(for: expectedPercent)
        )
    }
}
