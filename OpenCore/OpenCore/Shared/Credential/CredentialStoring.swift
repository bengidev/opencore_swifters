import Foundation

/// Proxy contract for opaque provider secrets. Feature code reads lazily at
/// request time so credential edits take effect on the next API call.
nonisolated protocol CredentialStoring: Sendable {
    func secret(for providerID: String) -> String?
    func save(_ secret: String, for providerID: String) throws
    func clear(for providerID: String) throws
}
