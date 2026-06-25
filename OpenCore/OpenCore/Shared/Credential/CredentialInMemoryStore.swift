import Foundation

/// In-memory `CredentialStoring` test double. Thread-safe and Keychain-free.
nonisolated final class CredentialInMemoryStore: CredentialStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var secrets: [String: String] = [:]

    init() {}

    func secret(for providerID: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard let value = secrets[providerID], !value.isEmpty else { return nil }
        return value
    }

    func save(_ secret: String, for providerID: String) throws {
        lock.lock()
        defer { lock.unlock() }
        secrets[providerID] = secret
    }

    func clear(for providerID: String) throws {
        lock.lock()
        defer { lock.unlock() }
        secrets.removeValue(forKey: providerID)
    }
}
