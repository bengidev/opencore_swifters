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
        #expect(strategy.identifier == "fallback")
    }

    @Test("makeOnDeviceOnly returns OnDeviceSpeechRecognitionStrategy")
    func makeOnDeviceOnly() {
        let strategy = SpeechRecognitionStrategyFactory.makeOnDeviceOnly()
        #expect(strategy.identifier == "on-device")
    }
}

@Suite("Remote Speech Transcription")
struct RemoteTranscriptionStrategyTests {
    @Test("hasCredential returns false when no credential exists")
    func hasCredentialDeniedWithoutCredential() {
        let store = CredentialInMemoryStore()
        let strategy = RemoteSpeechRecognitionStrategy(credentialStore: store)
        #expect(strategy.hasCredential() == false)
    }

    @Test("hasCredential returns true when credential exists")
    func hasCredentialAuthorizedWithCredential() throws {
        let store = CredentialInMemoryStore()
        try store.save("sk-test-key", for: "openai")
        let strategy = RemoteSpeechRecognitionStrategy(credentialStore: store)
        #expect(strategy.hasCredential() == true)
    }

    @Test("transcribe returns failure message when credential is missing")
    func transcribeMissingCredential() async throws {
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".caf")
        FileManager.default.createFile(atPath: audioURL.path, contents: Data([0x01]))
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let store = CredentialInMemoryStore()
        let strategy = RemoteSpeechRecognitionStrategy(credentialStore: store)
        let result = await strategy.transcribe(
            audioFileURL: audioURL,
            waveformSamples: [],
            duration: 1
        )

        #expect(result?.failureMessage != nil)
        #expect(result?.transcript.isEmpty == true)
    }

    @Test("transcribe surfaces HTTP errors from Whisper API")
    func transcribeHTTPError() async throws {
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".caf")
        FileManager.default.createFile(atPath: audioURL.path, contents: Data([0x01, 0x02]))
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [WhisperHTTPErrorURLProtocol.self]
        let session = URLSession(configuration: config)

        let store = CredentialInMemoryStore()
        try store.save("sk-test", for: "openai")
        let strategy = RemoteSpeechRecognitionStrategy(
            credentialStore: store,
            urlSession: session
        )

        let result = await strategy.transcribe(
            audioFileURL: audioURL,
            waveformSamples: [],
            duration: 1
        )

        #expect(result?.failureMessage?.contains("API key") == true)
        #expect(result?.transcript.isEmpty == true)
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

    @Test("fallback propagates remote transcription failure")
    func fallbackPropagatesRemoteFailure() async throws {
        let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        FileManager.default.createFile(atPath: audioURL.path, contents: Data([0x01]))
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let primary = StubSpeechRecognitionStrategy(
            identifier: "stub-primary",
            stopResult: SpeechRecognitionResult(transcript: "", audioFileURL: audioURL, duration: 2)
        )
        let remote = StubPostRecordingTranscriber(
            result: SpeechRecognitionResult(
                transcript: "",
                audioFileURL: audioURL,
                duration: 2,
                failureMessage: "Voice transcription failed."
            )
        )
        let fallback = FallbackSpeechRecognitionStrategy(primary: primary, remoteTranscriber: remote)

        let result = await fallback.stop()

        #expect(result?.failureMessage == "Voice transcription failed.")
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

private final class WhisperHTTPErrorURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.path.contains("audio/transcriptions") == true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
