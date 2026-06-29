import Foundation

/// Errors surfaced when media text extraction fails.
enum VisionExtractionError: Error, Equatable, Sendable {
    case unsupportedMedia
    case fileTooLarge
    case unreadableContent
    case noTextFound
}

extension VisionExtractionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unsupportedMedia:
            return "That file type is not supported for text extraction."
        case .fileTooLarge:
            return "The file is too large to extract as text."
        case .unreadableContent:
            return "The file could not be read as text."
        case .noTextFound:
            return "No readable text was found in that file."
        }
    }
}
