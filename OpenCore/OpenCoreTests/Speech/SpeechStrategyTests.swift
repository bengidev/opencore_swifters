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
        let fallback = FallbackSpeechRecognitionStrategy(primary: primary, remote: remote)
        #expect(fallback.identifier == "fallback")
    }

    @Test("fallback delegates authorizationStatus to primary")
    func fallbackDelegatesAuth() {
        let primary = OnDeviceSpeechRecognitionStrategy(locale: Locale(identifier: "en-US"))
        let store = CredentialInMemoryStore()
        let remote = RemoteSpeechRecognitionStrategy(credentialStore: store)
        let fallback = FallbackSpeechRecognitionStrategy(primary: primary, remote: remote)
        // Primary returns .authorized when no auth needed (on-device)
        #expect(fallback.authorizationStatus() == primary.authorizationStatus())
    }
}
