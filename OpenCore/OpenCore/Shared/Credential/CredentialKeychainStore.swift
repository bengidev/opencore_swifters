import Foundation
import Security

nonisolated struct CredentialKeychainError: Error, Equatable {
    let status: OSStatus

    init(status: OSStatus) {
        self.status = status
    }
}

/// Keychain-backed `CredentialStoring` adapter. Items are device-only and never
/// sync to iCloud.
nonisolated struct CredentialKeychainStore: CredentialStoring {
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
        let status = SecItemCopyMatching(query as CFDictionary, &item)
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
            guard addStatus == errSecSuccess else { throw CredentialKeychainError(status: addStatus) }
            return
        }

        throw CredentialKeychainError(status: updateStatus)
    }

    func clear(for providerID: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: providerID)
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialKeychainError(status: status)
        }
    }
}

extension CredentialKeychainStore {
    nonisolated static let openCoreService = "io.github.bengidev.OpenCore"
}
