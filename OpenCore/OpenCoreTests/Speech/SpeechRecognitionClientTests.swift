import Foundation
import Testing

@testable import OpenCore

@Suite("Speech Recognition Client")
struct SpeechRecognitionClientTests {
    @Test("live with credential store selects fallback strategy")
    func liveWithCredentialStoreUsesFallback() {
        let store = CredentialInMemoryStore()
        try? store.save("sk-test", for: "openai")
        let client = SpeechRecognitionClient.live(credentialStore: store)
        let strategy = SpeechRecognitionStrategyFactory.makeDefault(credentialStore: store)

        #expect(strategy.identifier == "fallback")
        #expect(client.authorizationStatus() == strategy.authorizationStatus())
    }

    @Test("strategy adapter forwards authorization and stop")
    func strategyAdapterForwardsCalls() async throws {
        let stub = StubSpeechRecognitionStrategy(
            identifier: "adapter-stub",
            stopResult: SpeechRecognitionResult(transcript: "wired")
        )
        let client = SpeechRecognitionClient(strategy: stub)

        #expect(client.authorizationStatus() == .authorized)
        let result = await client.stop()
        #expect(result?.transcript == "wired")
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
