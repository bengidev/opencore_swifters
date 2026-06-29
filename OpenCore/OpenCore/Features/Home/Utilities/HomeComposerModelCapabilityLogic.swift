import Foundation

/// Composer warnings for model capability mismatches.
nonisolated enum HomeComposerModelCapabilityLogic: Sendable {
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

    static func visualInputWarningMessage(
        modelName: String,
        attachments: [ChatMessageAttachment]
    ) -> String {
        let hasImages = hasImageAttachments(attachments)
        let hasVideos = hasVideoAttachments(attachments)

        switch (hasImages, hasVideos) {
        case (true, true):
            return "\(modelName) does not support the attached photos and videos. They will not be understood by the model."
        case (true, false):
            return imageInputWarningMessage(modelName: modelName)
        case (false, true):
            return "\(modelName) does not support video input. Attached videos will not be understood by the model."
        case (false, false):
            return "\(modelName) does not support this attachment type."
        }
    }

    static func imageInputWarningMessage(modelName: String) -> String {
        "\(modelName) does not support image input. Attached photos will not be understood by the model."
    }
}
