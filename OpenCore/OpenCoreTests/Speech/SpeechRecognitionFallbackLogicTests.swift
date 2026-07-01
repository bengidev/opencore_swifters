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

    @Test("retries after assistant on-device error codes")
    func retriesAfterAssistantErrorCodes() {
        let error = NSError(domain: "kAFAssistantErrorDomain", code: 1110)
        #expect(
            SpeechRecognitionFallbackLogic.shouldRetryWithServerRecognition(
                errorMessage: "The operation could not be completed.",
                attemptedOnDevice: true,
                error: error
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
