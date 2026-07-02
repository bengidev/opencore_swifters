import Foundation

/// Retention rules for persisted voice-note audio files.
nonisolated enum ChatVoiceAttachmentRetention: Sendable {
    /// Voice-note audio is removed one week after the message was sent.
    static let retentionInterval: TimeInterval = 7 * 24 * 60 * 60

    static func expirationCutoff(from now: Date = .now) -> Date {
        now.addingTimeInterval(-retentionInterval)
    }

    static func expireVoiceAttachments(
        in messages: [ChatMessage],
        cutoff: Date
    ) -> (messages: [ChatMessage], removedPaths: [String]) {
        var removedPaths: [String] = []
        let updated = messages.map { message -> ChatMessage in
            guard case let .text(text) = message else { return message }
            let (updatedText, paths) = expireVoiceAttachments(in: text, cutoff: cutoff)
            removedPaths.append(contentsOf: paths)
            return .text(
                id: updatedText.id,
                role: updatedText.role,
                content: updatedText.content,
                isComplete: updatedText.isComplete,
                timestamp: updatedText.timestamp,
                attachments: updatedText.attachments,
                modelContent: updatedText.modelContent
            )
        }
        return (updated, removedPaths)
    }

    static func expireVoiceAttachments(
        in message: ChatTextMessage,
        cutoff: Date
    ) -> (ChatTextMessage, removedPaths: [String]) {
        guard message.timestamp < cutoff else { return (message, []) }

        var removedPaths: [String] = []
        var keptAttachments: [ChatMessageAttachment] = []
        var promotedTranscript: String?

        for attachment in message.attachments {
            guard attachment.kind == .audio,
                  attachment.speechTranscript != nil else {
                keptAttachments.append(attachment)
                continue
            }

            removedPaths.append(attachment.localPath)
            if message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let transcript = attachment.speechTranscript?.trimmingCharacters(in: .whitespacesAndNewlines),
               !transcript.isEmpty {
                promotedTranscript = transcript
            }
        }

        guard !removedPaths.isEmpty else { return (message, []) }

        var updated = message
        updated.attachments = keptAttachments
        if let promotedTranscript {
            updated.content = promotedTranscript
        }
        return (updated, removedPaths)
    }
}
