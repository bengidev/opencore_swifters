import Foundation
import UniformTypeIdentifiers

/// Resolves a picked file into a supported vision extraction category.
nonisolated enum VisionMediaKindResolver: Sendable {
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

    static func resolve(pathExtension: String) -> VisionMediaKind {
        let normalized = pathExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return .unsupported }

        if plainTextExtensions.contains(normalized) { return .plainText }
        if imageExtensions.contains(normalized) { return .image }
        if videoExtensions.contains(normalized) { return .video }
        return .unsupported
    }

    static func resolve(contentType: UTType) -> VisionMediaKind {
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
