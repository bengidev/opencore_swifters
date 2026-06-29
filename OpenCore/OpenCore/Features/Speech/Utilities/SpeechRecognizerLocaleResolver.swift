import Foundation

/// Picks the best available `SFSpeechRecognizer` locale without hardcoding a single language.
nonisolated enum SpeechRecognizerLocaleResolver: Sendable {
    static func resolve(
        preferred: Locale = .current,
        isAvailable: (Locale) -> Bool
    ) -> Locale? {
        if isAvailable(preferred) {
            return preferred
        }

        if let languageCode = preferred.language.languageCode?.identifier {
            let languageOnly = Locale(identifier: languageCode)
            if isAvailable(languageOnly) {
                return languageOnly
            }
        }

        for identifier in Locale.preferredLanguages {
            let locale = Locale(identifier: identifier)
            if isAvailable(locale) {
                return locale
            }
        }

        let english = Locale(identifier: "en-US")
        if isAvailable(english) {
            return english
        }

        return nil
    }
}
