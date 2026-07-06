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

    static func hasFileAttachments(_ attachments: [ChatMessageAttachment]) -> Bool {
        attachments.contains { $0.kind == .file }
    }

    static func hasUnsupportedAttachments(
        attachments: [ChatMessageAttachment],
        capabilities: ModelInputCapabilities
    ) -> Bool {
        if hasImageAttachments(attachments), !capabilities.supportsImageInput {
            return true
        }
        if hasVideoAttachments(attachments), !capabilities.supportsVideoInput {
            return true
        }
        if hasFileAttachments(attachments), !capabilities.supportsFileInput {
            return true
        }
        return false
    }

    static func hasUnsupportedVisualAttachments(
        attachments: [ChatMessageAttachment],
        model: ChatModel?
    ) -> Bool {
        hasUnsupportedAttachments(
            attachments: attachments,
            capabilities: capabilities(for: model)
        )
    }

    static func validateDraft(
        attachments: [ChatMessageAttachment],
        capabilities: ModelInputCapabilities,
        modelName: String
    ) -> VisualAttachmentDecision {
        guard hasUnsupportedAttachments(attachments: attachments, capabilities: capabilities) else {
            return .allowed
        }
        return .blocked(message: visualInputWarningMessage(modelName: modelName, attachments: attachments))
    }

    static func validateDraft(
        attachments: [ChatMessageAttachment],
        model: ChatModel?,
        modelName: String
    ) -> VisualAttachmentDecision {
        validateDraft(
            attachments: attachments,
            capabilities: capabilities(for: model),
            modelName: modelName
        )
    }

    static func validateNewAttachment(
        _ attachment: ChatMessageAttachment,
        capabilities: ModelInputCapabilities,
        modelName: String
    ) -> VisualAttachmentDecision {
        switch attachment.kind {
        case .file where !capabilities.supportsFileInput:
            return .blocked(message: fileInputAttachWarningMessage(modelName: modelName))
        case .image where !capabilities.supportsImageInput:
            return .blocked(message: imageInputWarningMessage(modelName: modelName))
        case .video where !capabilities.supportsVideoInput:
            return .blocked(
                message: "\(modelName) does not support video input. Choose a video-capable model to attach videos."
            )
        case .image, .video, .file, .audio:
            return .allowed
        }
    }

    static func validateNewAttachment(
        _ attachment: ChatMessageAttachment,
        model: ChatModel?,
        modelName: String
    ) -> VisualAttachmentDecision {
        validateNewAttachment(
            attachment,
            capabilities: capabilities(for: model),
            modelName: modelName
        )
    }

    static func visualInputWarningMessage(
        modelName: String,
        attachments: [ChatMessageAttachment]
    ) -> String {
        let hasImages = hasImageAttachments(attachments)
        let hasVideos = hasVideoAttachments(attachments)
        let hasFiles = hasFileAttachments(attachments)

        switch (hasImages, hasVideos, hasFiles) {
        case (true, true, _):
            return "\(modelName) does not support the attached photos and videos. Choose a vision-capable model before sending."
        case (true, false, false):
            return imageInputWarningMessage(modelName: modelName)
        case (false, true, false):
            return "\(modelName) does not support video input. Choose a video-capable model before sending."
        case (false, false, true):
            return fileInputSendWarningMessage(modelName: modelName)
        case (false, false, false):
            return "\(modelName) does not support this attachment type."
        default:
            return "\(modelName) does not support this attachment type."
        }
    }

    static func imageInputWarningMessage(modelName: String) -> String {
        "\(modelName) does not support image input. Choose a vision-capable model before sending."
    }

    static func fileInputAttachWarningMessage(modelName: String) -> String {
        "\(modelName) does not support file input. Choose a file-capable model to attach files."
    }

    static func fileInputSendWarningMessage(modelName: String) -> String {
        "\(modelName) does not support file input. Choose a file-capable model before sending."
    }

    private static func capabilities(for model: ChatModel?) -> ModelInputCapabilities {
        guard let model else {
            return ModelInputCapabilities(inputModalities: [.text])
        }
        return ModelInputCapabilities.from(model)
    }
}
