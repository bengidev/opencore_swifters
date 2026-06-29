import Foundation

/// Strategy for decoding plain-text file payloads into composer text.
nonisolated enum VisionPlainTextExtractor: Sendable {
    static let maxByteCount = 512_000

    static func extract(from data: Data) throws -> String {
        guard data.count <= maxByteCount else {
            throw VisionExtractionError.fileTooLarge
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw VisionExtractionError.unreadableContent
        }
        return text
    }
}
