import Foundation

/// Pure rules for on-device vs server speech recognition fallback.
nonisolated enum SpeechRecognitionFallbackLogic: Sendable {
    static func prefersOnDeviceRecognition(supportsOnDevice: Bool) -> Bool {
        supportsOnDevice
    }

    static func shouldRetryWithServerRecognition(
        errorMessage: String,
        attemptedOnDevice: Bool
    ) -> Bool {
        guard attemptedOnDevice else { return false }

        let lowered = errorMessage.lowercased()
        return lowered.contains("initialize")
            || lowered.contains("on-device")
            || lowered.contains("on device")
            || lowered.contains("not downloaded")
            || lowered.contains("not available")
    }

    static func userFacingErrorMessage(systemMessage: String) -> String {
        let lowered = systemMessage.lowercased()

        if lowered.contains("permission") || lowered.contains("authorized") || lowered.contains("denied") {
            return "Microphone and speech recognition access are required for voice input."
        }

        if lowered.contains("locale") || lowered.contains("language") {
            return "Speech recognition is not available for your language on this device."
        }

        if shouldRetryWithServerRecognition(errorMessage: systemMessage, attemptedOnDevice: true) {
            return "Speech recognition could not be started. Check your network connection."
        }

        return systemMessage
    }
}
