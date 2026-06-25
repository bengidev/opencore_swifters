import Foundation
import Testing

@testable import OpenCore

@Suite("Credential Storing")
struct CredentialStoringTests {
    private let providerID = "openrouter"

    private func makeStore() -> any CredentialStoring {
        CredentialInMemoryStore()
    }

    @Test("save and secret round-trip")
    func saveAndSecretRoundTrip() throws {
        let store = makeStore()

        try store.save("sk-test", for: providerID)

        #expect(store.secret(for: providerID) == "sk-test")
    }

    @Test("clear removes secret")
    func clearRemovesSecret() throws {
        let store = makeStore()
        try store.save("sk-test", for: providerID)

        try store.clear(for: providerID)

        #expect(store.secret(for: providerID) == nil)
    }

    @Test("secret returns nil for empty stored value")
    func secretReturnsNilForEmptyStoredValue() throws {
        let store = makeStore()
        try store.save("", for: providerID)

        #expect(store.secret(for: providerID) == nil)
    }

    @Test("clear on absent secret does not throw")
    func clearOnAbsentSecretDoesNotThrow() throws {
        let store = makeStore()

        try store.clear(for: providerID)
    }
}
