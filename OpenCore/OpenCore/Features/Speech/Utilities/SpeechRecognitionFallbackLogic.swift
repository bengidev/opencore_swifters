import Foundation

/// Pure rules for on-device vs server speech recognition fallback.
nonisolated enum SpeechRecognitionFallbackLogic: Sendable {
    static func shouldRetryWithServerRecognition(
        errorMessage: String,
        attemptedOnDevice: Bool,
        error: NSError? = nil
    ) -> Bool {
        guard attemptedOnDevice else { return false }

        if let error, isRetryableOnDeviceAssistantError(error) {
            return true
        }

        let lowered = errorMessage.lowercased()
        return lowered.contains("initialize")
            || lowered.contains("on-device")
            || lowered.contains("on device")
            || lowered.contains("not downloaded")
            || lowered.contains("not available")
            || lowered.contains("siri")
            || lowered.contains("dictation")
    }

    private static func isRetryableOnDeviceAssistantError(_ error: NSError) -> Bool {
        if error.domain == "kAFAssistantErrorDomain", error.code == 1110 {
            return true
        }
        if error.domain == "com.apple.speech.recognition" {
            return true
        }
        return false
    }

    static func userFacingErrorMessage(
        systemMessage: String,
        attemptedOnDevice: Bool = false
    ) -> String {
        let lowered = systemMessage.lowercased()

        if lowered.contains("permission") || lowered.contains("authorized") || lowered.contains("denied") {
            return "Microphone and speech recognition access are required for voice input."
        }

        if lowered.contains("locale") || lowered.contains("language") {
            return "Speech recognition is not available for your language on this device."
        }

        if shouldRetryWithServerRecognition(
            errorMessage: systemMessage,
            attemptedOnDevice: attemptedOnDevice
        ) {
            return "Speech recognition could not be started. Check your network connection."
        }

        return systemMessage
    }
}
