import Foundation
import Security

/// A minimal secure store for provider secrets, keyed by provider identifier.
///
/// Feature-internal security abstraction behind which the live Keychain adapter
/// and an in-memory test double both sit. It names no chat domain types and is
/// feature-neutral: it stores, reads, and clears opaque secret strings per provider.
///
/// The secret is read lazily, never cached by callers, so editing
/// the key takes effect on the next read with no stale value.
///
/// Declared `nonisolated` so the live adapter can be read at request time from
/// the streaming client's `nonisolated`/`@Sendable` credential closure, even
/// though the app target's default actor isolation is `MainActor`.
nonisolated protocol SidePanelCredentialStore: Sendable {
    /// The currently stored secret for the given provider, or `nil` when none is stored.
    func secret(for providerID: String) -> String?
    /// Persists `secret` for the given provider, replacing any existing value.
    func save(_ secret: String, for providerID: String) throws
    /// Removes any stored secret for the given provider. Removing an absent secret is not an error.
    func clear(for providerID: String) throws
}

// MARK: - Keychain adapter

/// A typed wrapper over a Keychain `OSStatus` failure.
nonisolated struct SidePanelKeychainError: Error, Equatable {
    let status: OSStatus

    init(status: OSStatus) {
        self.status = status
    }
}

/// Live `SidePanelCredentialStore` backed by a Keychain generic-password item.
///
/// State is process-global and keyed by `service` + `account`, so every
/// instance configured with the same pair shares the same item. That is how the
/// Settings surface (which writes) and the streaming client's credential
/// provider (which reads at request time) stay in sync without sharing an
/// object: they address the same Keychain row.
///
/// The item is stored with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
/// so it is never written to iCloud Keychain or device backups.
nonisolated struct SidePanelKeychainCredentialStore: SidePanelCredentialStore {
    let service: String

    init(service: String) {
        self.service = service
    }

    private func account(for providerID: String) -> String {
        "\(providerID)-api-key"
    }

    func secret(for providerID: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: providerID),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = unsafe SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty
        else { return nil }
        return value
    }

    func save(_ secret: String, for providerID: String) throws {
        let data = Data(secret.utf8)
        let acct = account(for: providerID)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: acct
        ]

        // Try an in-place update first so we never duplicate the item.
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }

        if updateStatus == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw SidePanelKeychainError(status: addStatus) }
            return
        }

        throw SidePanelKeychainError(status: updateStatus)
    }

    func clear(for providerID: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: providerID)
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SidePanelKeychainError(status: status)
        }
    }
}

extension SidePanelKeychainCredentialStore {
    /// The shared Keychain service identifier for this app.
    static let openCoreService = "io.github.bengidev.OpenCore"
}

// MARK: - In-memory test double

/// Thread-safe in-memory `SidePanelCredentialStore` for tests and previews. Never touches
/// the Keychain, so test runs are hermetic and leave no device state behind.
nonisolated final class SidePanelInMemoryCredentialStore: SidePanelCredentialStore, @unchecked Sendable {
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
