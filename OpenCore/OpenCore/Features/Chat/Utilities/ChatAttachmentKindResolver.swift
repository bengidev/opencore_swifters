import Foundation
import UniformTypeIdentifiers

/// Resolves filenames and content types into chat attachment kinds.
nonisolated enum ChatAttachmentKindResolver: Sendable {
    private static let plainTextExtensions: Set<String> = [
        "txt", "md", "markdown", "json", "swift", "js", "ts", "py", "rb", "go",
        "rs", "java", "kt", "c", "cc", "cpp", "h", "hpp", "m", "mm", "sh",
        "yaml", "yml", "xml", "html", "css", "csv", "log"
    ]

    private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "bmp", "tiff", "tif"
    ]

    private static let videoExtensions: Set<String> = [
        "mp4", "mov", "m4v", "avi", "mkv"
    ]

    static func attachmentKind(
        filename: String,
        contentType: UTType?
    ) -> ChatMessageAttachmentKind {
        if let contentType {
            if contentType.conforms(to: .image) { return .image }
            if contentType.conforms(to: .movie) || contentType.conforms(to: .video) { return .video }
            if contentType.conforms(to: .audio) { return .audio }
            if contentType.conforms(to: .plainText) || contentType.conforms(to: .text) { return .file }
        }

        switch resolve(pathExtension: (filename as NSString).pathExtension) {
        case .plainText:
            return .file
        case .image:
            return .image
        case .video:
            return .video
        case .unsupported:
            return .file
        }
    }

    static func resolve(pathExtension: String) -> ChatAttachmentMediaCategory {
        let normalized = pathExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return .unsupported }

        if plainTextExtensions.contains(normalized) { return .plainText }
        if imageExtensions.contains(normalized) { return .image }
        if videoExtensions.contains(normalized) { return .video }
        return .unsupported
    }

    static func resolve(contentType: UTType) -> ChatAttachmentMediaCategory {
        if contentType.conforms(to: .plainText) || contentType.conforms(to: .text) {
            return .plainText
        }
        if contentType.conforms(to: .image) {
            return .image
        }
        if contentType.conforms(to: .movie) || contentType.conforms(to: .video) {
            return .video
        }
        return resolve(pathExtension: contentType.preferredFilenameExtension ?? "")
    }
}

nonisolated enum ChatAttachmentMediaCategory: Sendable {
    case plainText
    case image
    case video
    case unsupported
}
