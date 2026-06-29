import Foundation

nonisolated enum ChatAttachmentSizeLimits: Sendable {
    /// Maximum video payload encoded and sent to the provider.
    static let maxVideoBytes = 50 * 1024 * 1024

    /// Maximum size for any single attachment at import time.
    static let maxImportBytes = 100 * 1024 * 1024

    static func validateImportSize(byteCount: Int) throws {
        guard byteCount <= maxImportBytes else {
            throw ChatAttachmentError.importTooLarge(byteCount: byteCount, limit: maxImportBytes)
        }
    }

    static func validateVideoWireSize(byteCount: Int) throws {
        guard byteCount <= maxVideoBytes else {
            throw ChatAttachmentError.videoTooLarge(byteCount: byteCount, limit: maxVideoBytes)
        }
    }
}
