import Foundation
import UniformTypeIdentifiers

/// Builds provider-facing text from visible composer content and hidden attachment metadata.
nonisolated enum ChatModelInputBuilder: Sendable {
    static func modelContent(visibleText: String, attachments: [ChatMessageAttachment]) -> String {
        let sections = textSections(visibleText: visibleText, attachments: attachments)
        return sections.joined(separator: "\n\n")
    }

    static func textSections(
        visibleText: String,
        attachments: [ChatMessageAttachment]
    ) -> [String] {
        var sections: [String] = []

        for attachment in attachments where attachment.kind == .file {
            if let content = attachment.fileTextContent?.trimmingCharacters(in: .whitespacesAndNewlines),
               !content.isEmpty {
                sections.append("[Attached file: \(attachment.filename)]\n\(content)")
            }
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

        return sections
    }

    static func attachmentKind(
        filename: String,
        contentType: UTType?
    ) -> ChatMessageAttachmentKind {
        ChatAttachmentKindResolver.attachmentKind(filename: filename, contentType: contentType)
    }
}

import UniformTypeIdentifiers
