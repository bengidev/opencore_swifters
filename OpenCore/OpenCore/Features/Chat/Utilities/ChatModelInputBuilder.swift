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

        let trimmedVisible = visibleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let speechTranscripts = attachments
            .compactMap(\.speechTranscript)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for transcript in speechTranscripts where !sectionExists(transcript, in: sections) {
            if trimmedVisible.isEmpty
                || !trimmedVisible.localizedCaseInsensitiveContains(transcript) {
                sections.append(transcript)
            }
        }

        if !trimmedVisible.isEmpty {
            sections.append(trimmedVisible)
        }

        return sections
    }

    private static func sectionExists(_ candidate: String, in sections: [String]) -> Bool {
        sections.contains { $0.localizedCaseInsensitiveCompare(candidate) == .orderedSame }
    }

    static func attachmentKind(
        filename: String,
        contentType: UTType?
    ) -> ChatMessageAttachmentKind {
        ChatAttachmentKindResolver.attachmentKind(filename: filename, contentType: contentType)
    }
}
