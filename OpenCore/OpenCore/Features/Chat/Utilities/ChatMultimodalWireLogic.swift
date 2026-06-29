import Foundation

/// Builds OpenRouter multimodal `messages[].content` parts from composer attachments.
nonisolated enum ChatMultimodalWireLogic: Sendable {
    static func hasVisualMedia(_ attachments: [ChatMessageAttachment]) -> Bool {
        attachments.contains { $0.kind == .image || $0.kind == .video }
    }

    static func makeContentParts(
        visibleText: String,
        attachments: [ChatMessageAttachment]
    ) -> [ProviderChatContentPart]? {
        guard hasVisualMedia(attachments) else { return nil }

        var parts: [ProviderChatContentPart] = []

        if let text = combinedText(visibleText: visibleText, attachments: attachments),
           !text.isEmpty {
            parts.append(.text(text))
        }

        for attachment in attachments where attachment.kind == .image {
            guard let dataURL = ChatMultimodalImagePayloadLogic.dataURL(fromFileAt: attachment.localPath) else {
                continue
            }
            parts.append(.imageURL(dataURL))
        }

        for attachment in attachments where attachment.kind == .video {
            guard let dataURL = ChatMultimodalVideoPayloadLogic.dataURL(fromFileAt: attachment.localPath) else {
                continue
            }
            parts.append(.videoURL(dataURL))
        }

        return parts.isEmpty ? nil : parts
    }

    static func combinedText(
        visibleText: String,
        attachments: [ChatMessageAttachment]
    ) -> String? {
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
            sections.append("[Voice transcript]\n\(speechTranscripts.joined(separator: "\n\n"))")
        }

        let trimmedVisible = visibleText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedVisible.isEmpty {
            sections.append(trimmedVisible)
        }

        guard !sections.isEmpty else { return nil }
        return sections.joined(separator: "\n\n")
    }
}
