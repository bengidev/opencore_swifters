import Foundation
import UniformTypeIdentifiers

/// Builds provider-facing text from visible composer content and hidden attachment metadata.
nonisolated enum ChatModelInputBuilder: Sendable {
    static func modelContent(visibleText: String, attachments: [ChatMessageAttachment]) -> String {
        var sections: [String] = []

        let filePaths = attachments
            .filter { $0.kind == .file }
            .map(\.localPath)
        if !filePaths.isEmpty {
            let listing = filePaths.map { "- \($0)" }.joined(separator: "\n")
            sections.append("[Attached files]\n\(listing)")
        }

        let speechTranscripts = attachments
            .compactMap(\.speechTranscript)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !speechTranscripts.isEmpty {
            let listing = speechTranscripts.joined(separator: "\n\n")
            sections.append("[Voice transcript]\n\(listing)")
        }

        let trimmedVisible = visibleText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedVisible.isEmpty {
            sections.append(trimmedVisible)
        }

        return sections.joined(separator: "\n\n")
    }

    static func attachmentKind(
        filename: String,
        contentType: UTType?
    ) -> ChatMessageAttachmentKind {
        if let contentType {
            if contentType.conforms(to: .image) { return .image }
            if contentType.conforms(to: .movie) || contentType.conforms(to: .video) { return .video }
            if contentType.conforms(to: .audio) { return .audio }
        }

        switch VisionMediaKindResolver.resolve(pathExtension: (filename as NSString).pathExtension) {
        case .image:
            return .image
        case .video:
            return .video
        case .plainText:
            return .file
        case .unsupported:
            return .file
        }
    }
}
