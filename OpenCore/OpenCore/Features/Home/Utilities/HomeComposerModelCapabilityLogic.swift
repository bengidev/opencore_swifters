import Foundation

/// Composer warnings for model capability mismatches.
nonisolated enum HomeComposerModelCapabilityLogic: Sendable {
    enum VisualAttachmentDecision: Equatable, Sendable {
        case allowed
        case blocked(message: String)
    }

    static func supportsImageInput(for model: ChatModel?) -> Bool {
        model?.supportsImageInput == true
    }

    static func supportsVideoInput(for model: ChatModel?) -> Bool {
        model?.supportsVideoInput == true
    }

    static func hasImageAttachments(_ attachments: [ChatMessageAttachment]) -> Bool {
        attachments.contains { $0.kind == .image }
    }

    static func hasVideoAttachments(_ attachments: [ChatMessageAttachment]) -> Bool {
        attachments.contains { $0.kind == .video }
    }

    static func hasUnsupportedVisualAttachments(
        attachments: [ChatMessageAttachment],
        model: ChatModel?
    ) -> Bool {
        if hasImageAttachments(attachments), !supportsImageInput(for: model) {
            return true
        }
        if hasVideoAttachments(attachments), !supportsVideoInput(for: model) {
            return true
        }
        return false
    }

    static func validateDraft(
        attachments: [ChatMessageAttachment],
        model: ChatModel?,
        modelName: String
    ) -> VisualAttachmentDecision {
        guard hasUnsupportedVisualAttachments(attachments: attachments, model: model) else {
            return .allowed
        }
        return .blocked(message: visualInputWarningMessage(modelName: modelName, attachments: attachments))
    }

    static func validateNewAttachment(
        _ attachment: ChatMessageAttachment,
        model: ChatModel?,
        modelName: String
    ) -> VisualAttachmentDecision {
        switch attachment.kind {
        case .image where !supportsImageInput(for: model):
            return .blocked(message: imageInputWarningMessage(modelName: modelName))
        case .video where !supportsVideoInput(for: model):
            return .blocked(
                message: "\(modelName) does not support video input. Choose a video-capable model to attach videos."
            )
        case .image, .video, .file, .audio:
            return .allowed
        }
    }

    static func visualInputWarningMessage(
        modelName: String,
        attachments: [ChatMessageAttachment]
    ) -> String {
        let hasImages = hasImageAttachments(attachments)
        let hasVideos = hasVideoAttachments(attachments)

        switch (hasImages, hasVideos) {
        case (true, true):
            return "\(modelName) does not support the attached photos and videos. Choose a vision-capable model before sending."
        case (true, false):
            return imageInputWarningMessage(modelName: modelName)
        case (false, true):
            return "\(modelName) does not support video input. Choose a video-capable model before sending."
        case (false, false):
            return "\(modelName) does not support this attachment type."
        }
    }

    static func imageInputWarningMessage(modelName: String) -> String {
        "\(modelName) does not support image input. Choose a vision-capable model before sending."
    }
}
