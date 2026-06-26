import Foundation
import Testing

@testable import OpenCore

@Suite("Settings Context Compaction Preference Store")
struct SettingsContextCompactionPreferenceStoreTests {
    @Test("Default preference uses 90 percent threshold")
    func defaultThresholdIsNinety() {
        let store = SettingsInMemoryContextCompactionPreferenceStore()
        #expect(store.preference().triggerThresholdPercent == 90)
        #expect(store.preference().isEnabled == false)
    }

    @Test("UserDefaults store round-trips preference")
    func userDefaultsRoundTrip() {
        let suite = "SettingsContextCompactionPreferenceStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let store = SettingsUserDefaultsContextCompactionPreferenceStore(suiteName: suite)
        var preference = store.preference()
        preference.isEnabled = false
        preference.triggerThresholdPercent = 75
        store.setPreference(preference)

        let reloaded = SettingsUserDefaultsContextCompactionPreferenceStore(suiteName: suite)
        #expect(reloaded.preference().isEnabled == false)
        #expect(reloaded.preference().triggerThresholdPercent == 75)
    }
}
