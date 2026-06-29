import Foundation

nonisolated enum ChatAttachmentError: Error, Equatable, Sendable {
    case fileTooLarge
    case unreadableFile
    case videoTooLarge(byteCount: Int, limit: Int)
    case importTooLarge(byteCount: Int, limit: Int)
    case visualEncodingFailed(filename: String)
}

extension ChatAttachmentError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .fileTooLarge:
            return "The file is too large to attach as text."
        case .unreadableFile:
            return "The file could not be read as text."
        case let .videoTooLarge(byteCount, limit):
            let sizeMB = byteCount / (1024 * 1024)
            let limitMB = limit / (1024 * 1024)
            return "Video is too large (\(sizeMB) MB). Maximum size is \(limitMB) MB."
        case let .importTooLarge(byteCount, limit):
            let sizeMB = byteCount / (1024 * 1024)
            let limitMB = limit / (1024 * 1024)
            return "Attachment is too large (\(sizeMB) MB). Maximum size is \(limitMB) MB."
        case let .visualEncodingFailed(filename):
            return "Could not prepare \(filename) for sending."
        }
    }
}
