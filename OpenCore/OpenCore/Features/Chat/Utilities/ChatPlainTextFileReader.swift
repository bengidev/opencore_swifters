import Foundation

/// Reads plain-text file payloads for model input.
nonisolated enum ChatPlainTextFileReader: Sendable {
    static let maxByteCount = 512_000

    static func read(from data: Data) throws -> String {
        guard data.count <= maxByteCount else {
            throw ChatAttachmentError.fileTooLarge
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw ChatAttachmentError.unreadableFile
        }
        return text
    }

    static func read(fromFileAt localPath: String) throws -> String {
        let data = try Data(contentsOf: URL(fileURLWithPath: localPath))
        return try read(from: data)
    }
}
