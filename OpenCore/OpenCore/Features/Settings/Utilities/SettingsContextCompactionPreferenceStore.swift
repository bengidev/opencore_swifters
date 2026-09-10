import Foundation

/// Store for context compaction preferences.
nonisolated protocol SettingsContextCompactionPreferenceStore: Sendable {
    func preference() -> SettingsContextCompactionPreference
    func setPreference(_ preference: SettingsContextCompactionPreference)
}

nonisolated struct SettingsUserDefaultsContextCompactionPreferenceStore: SettingsContextCompactionPreferenceStore {
    private enum Key {
        static let preference = "opencore.context.compaction.v1"
    }

    let suiteName: String?

    init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        guard let suiteName else { return .standard }
        return UserDefaults(suiteName: suiteName) ?? .standard
    }

    func preference() -> SettingsContextCompactionPreference {
        guard let data = defaults.data(forKey: Key.preference),
              var decoded = try? JSONDecoder().decode(SettingsContextCompactionPreference.self, from: data) else {
            return SettingsContextCompactionPreference()
        }

        let beforeNormalization = decoded
        decoded.normalizeAfterDecoding()
        if decoded != beforeNormalization {
            setPreference(decoded)
        }
        return decoded
    }

    func setPreference(_ preference: SettingsContextCompactionPreference) {
        guard let data = try? JSONEncoder().encode(preference) else { return }
        defaults.set(data, forKey: Key.preference)
    }
}

nonisolated final class SettingsInMemoryContextCompactionPreferenceStore: SettingsContextCompactionPreferenceStore, @unchecked Sendable {
    private var stored = SettingsContextCompactionPreference()

    func preference() -> SettingsContextCompactionPreference {
        stored
    }

    func setPreference(_ preference: SettingsContextCompactionPreference) {
        stored = preference
    }
}
