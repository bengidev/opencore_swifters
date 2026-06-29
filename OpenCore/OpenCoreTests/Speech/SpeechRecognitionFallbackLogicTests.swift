import Foundation
import Testing

@testable import OpenCore

@Suite("Speech Recognition Fallback Logic")
struct SpeechRecognitionFallbackLogicTests {
    @Test("retries with server after on-device initialization failure")
    func retriesAfterOnDeviceInitializationFailure() {
        #expect(
            SpeechRecognitionFallbackLogic.shouldRetryWithServerRecognition(
                errorMessage: "Failed to initialize recognizer",
                attemptedOnDevice: true
            ) == true
        )
        #expect(
            SpeechRecognitionFallbackLogic.shouldRetryWithServerRecognition(
                errorMessage: "On-device recognition is not available",
                attemptedOnDevice: true
            ) == true
        )
    }

    @Test("does not retry when server recognition already failed")
    func doesNotRetryAfterServerFailure() {
        #expect(
            SpeechRecognitionFallbackLogic.shouldRetryWithServerRecognition(
                errorMessage: "Failed to initialize recognizer",
                attemptedOnDevice: false
            ) == false
        )
    }

    @Test("maps initialization errors to a clearer message")
    func mapsInitializationErrors() {
        let message = SpeechRecognitionFallbackLogic.userFacingErrorMessage(
            systemMessage: "Failed to initialize recognizer",
            attemptedOnDevice: true
        )

        #expect(message.contains("network"))
    }
}
