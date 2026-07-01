import Foundation
import Testing

@testable import OpenCore

@Suite("Speech Strategy Factory")
struct SpeechStrategyFactoryTests {
    @Test("makeDefault without credential returns OnDeviceSpeechRecognitionStrategy")
    func makeDefaultWithoutCredential() {
        let strategy = SpeechRecognitionStrategyFactory.makeDefault()
        #expect(strategy.identifier == "on-device")
    }

    @Test("makeDefault with credential returns FallbackSpeechRecognitionStrategy")
    func makeDefaultWithCredential() {
        let store = CredentialInMemoryStore()
        try? store.save("sk-test", for: "openai")
        let strategy = SpeechRecognitionStrategyFactory.makeDefault(credentialStore: store)
        #expect(strategy.identifier == "fallback")
    }

    @Test("makeDefault with empty credential store returns FallbackSpeechRecognitionStrategy")
    func makeDefaultWithEmptyCredential() {
        let store = CredentialInMemoryStore()
        let strategy = SpeechRecognitionStrategyFactory.makeDefault(credentialStore: store)
        // Even without a credential for "openai", the factory builds a fallback
        // strategy — the remote strategy inside will report .denied on auth check.
        #expect(strategy.identifier == "fallback")
    }

    @Test("makeOnDeviceOnly returns OnDeviceSpeechRecognitionStrategy")
    func makeOnDeviceOnly() {
        let strategy = SpeechRecognitionStrategyFactory.makeOnDeviceOnly()
        #expect(strategy.identifier == "on-device")
    }

    @Test("makeRemoteOnly returns RemoteSpeechRecognitionStrategy")
    func makeRemoteOnly() {
        let store = CredentialInMemoryStore()
        let strategy = SpeechRecognitionStrategyFactory.makeRemoteOnly(credentialStore: store)
        #expect(strategy.identifier == "remote")
    }
}

@Suite("Remote Speech Recognition Strategy - Authorization")
struct RemoteAuthStrategyTests {
    @Test("authorizationStatus returns denied when no credential exists")
    func authDeniedWithoutCredential() {
        let store = CredentialInMemoryStore()
        let strategy = RemoteSpeechRecognitionStrategy(credentialStore: store)
        #expect(strategy.authorizationStatus() == .denied)
    }

    @Test("authorizationStatus returns authorized when credential exists")
    func authAuthorizedWithCredential() throws {
        let store = CredentialInMemoryStore()
        try store.save("sk-test-key", for: "openai")
        let strategy = RemoteSpeechRecognitionStrategy(credentialStore: store)
        #expect(strategy.authorizationStatus() == .authorized)
    }

    @Test("authorizationStatus uses custom provider id")
    func authWithCustomProviderID() throws {
        let store = CredentialInMemoryStore()
        try store.save("sk-whisper-key", for: "whisper")
        let strategy = RemoteSpeechRecognitionStrategy(
            credentialStore: store,
            credentialProviderID: "whisper"
        )
        #expect(strategy.authorizationStatus() == .authorized)
    }

    @Test("authorizationStatus returns denied for wrong provider id")
    func authDeniedForWrongProviderID() throws {
        let store = CredentialInMemoryStore()
        try store.save("sk-test", for: "openrouter")
        let strategy = RemoteSpeechRecognitionStrategy(credentialStore: store)
        #expect(strategy.authorizationStatus() == .denied)
    }

    @Test("requestAuthorization mirrors denied status")
    func requestAuthDenied() async {
        let store = CredentialInMemoryStore()
        let strategy = RemoteSpeechRecognitionStrategy(credentialStore: store)
        let status = await strategy.requestAuthorization()
        #expect(status == .denied)
    }

    @Test("requestAuthorization mirrors authorized status")
    func requestAuthAuthorized() async throws {
        let store = CredentialInMemoryStore()
        try store.save("sk-test", for: "openai")
        let strategy = RemoteSpeechRecognitionStrategy(credentialStore: store)
        let status = await strategy.requestAuthorization()
        #expect(status == .authorized)
    }
}

@Suite("Fallback Speech Recognition Strategy")
struct FallbackStrategyTests {
    @Test("fallback identifier is 'fallback'")
    func fallbackHasCorrectIdentifier() {
        let primary = OnDeviceSpeechRecognitionStrategy(locale: Locale(identifier: "en-US"))
        let store = CredentialInMemoryStore()
        let remote = RemoteSpeechRecognitionStrategy(credentialStore: store)
        let fallback = FallbackSpeechRecognitionStrategy(primary: primary, remoteTranscriber: remote)
        #expect(fallback.identifier == "fallback")
    }

    @Test("fallback delegates authorizationStatus to primary")
    func fallbackDelegatesAuth() {
        let primary = OnDeviceSpeechRecognitionStrategy(locale: Locale(identifier: "en-US"))
        let store = CredentialInMemoryStore()
        let remote = RemoteSpeechRecognitionStrategy(credentialStore: store)
        let fallback = FallbackSpeechRecognitionStrategy(primary: primary, remoteTranscriber: remote)
        // Primary returns .authorized when no auth needed (on-device)
        #expect(fallback.authorizationStatus() == primary.authorizationStatus())
    }

    @Test("fallback returns primary transcript when non-empty")
    func fallbackUsesPrimaryTranscript() async throws {
        let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        FileManager.default.createFile(atPath: audioURL.path, contents: Data([0x01]))
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let primary = StubSpeechRecognitionStrategy(
            identifier: "stub-primary",
            stopResult: SpeechRecognitionResult(transcript: "hello", audioFileURL: audioURL, duration: 1)
        )
        let remote = StubPostRecordingTranscriber(
            result: SpeechRecognitionResult(transcript: "remote", audioFileURL: audioURL, duration: 1)
        )
        let fallback = FallbackSpeechRecognitionStrategy(primary: primary, remoteTranscriber: remote)

        let result = await fallback.stop()

        #expect(result?.transcript == "hello")
        #expect(remote.transcribeCallCount == 0)
    }

    @Test("fallback transcribes captured audio when primary transcript is empty")
    func fallbackTranscribesCapturedAudio() async throws {
        let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        FileManager.default.createFile(atPath: audioURL.path, contents: Data([0x01]))
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let primary = StubSpeechRecognitionStrategy(
            identifier: "stub-primary",
            stopResult: SpeechRecognitionResult(transcript: "   ", audioFileURL: audioURL, duration: 2)
        )
        let remote = StubPostRecordingTranscriber(
            result: SpeechRecognitionResult(transcript: "from whisper", audioFileURL: audioURL, duration: 2)
        )
        let fallback = FallbackSpeechRecognitionStrategy(primary: primary, remoteTranscriber: remote)

        let result = await fallback.stop()

        #expect(result?.transcript == "from whisper")
        #expect(remote.transcribeCallCount == 1)
    }
}

private final class StubSpeechRecognitionStrategy: SpeechRecognitionStrategy, @unchecked Sendable {
    let identifier: String
    var stopResult: SpeechRecognitionResult?

    init(identifier: String, stopResult: SpeechRecognitionResult? = nil) {
        self.identifier = identifier
        self.stopResult = stopResult
    }

    func authorizationStatus() -> SpeechAuthorizationStatus { .authorized }

    func requestAuthorization() async -> SpeechAuthorizationStatus { .authorized }

    func start() -> AsyncStream<SpeechRecognitionEvent> {
        AsyncStream { $0.finish() }
    }

    func stop() async -> SpeechRecognitionResult? { stopResult }
}

private final class StubPostRecordingTranscriber: SpeechPostRecordingTranscriber, @unchecked Sendable {
    let result: SpeechRecognitionResult?
    private(set) var transcribeCallCount = 0

    init(result: SpeechRecognitionResult?) {
        self.result = result
    }

    func transcribe(
        audioFileURL: URL,
        waveformSamples: [Float],
        duration: TimeInterval
    ) async -> SpeechRecognitionResult? {
        transcribeCallCount += 1
        return result
    }
}
