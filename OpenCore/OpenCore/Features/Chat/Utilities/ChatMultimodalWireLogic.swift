import Foundation
import UIKit

/// Builds OpenRouter multimodal `messages[].content` parts from composer attachments.
nonisolated enum ChatMultimodalWireLogic: Sendable {
    static func hasVisualMedia(_ attachments: [ChatMessageAttachment]) -> Bool {
        attachments.contains { $0.kind == .image || $0.kind == .video }
    }

    static func hasPersistedVisualWire(_ attachments: [ChatMessageAttachment]) -> Bool {
        attachments.contains {
            ($0.kind == .image && $0.wireImageDataURL != nil)
                || ($0.kind == .video && $0.wireVideoDataURL != nil)
        }
    }

    /// Encodes visual attachments for send and returns copies with persisted wire payloads.
    static func prepareAttachmentsForSend(
        attachments: [ChatMessageAttachment],
        modelText: String
    ) throws -> [ChatMessageAttachment] {
        guard hasVisualMedia(attachments) else { return attachments }

        var prepared = attachments
        var parts: [ProviderChatContentPart] = []

        let trimmedModelText = modelText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedModelText.isEmpty {
            parts.append(.text(trimmedModelText))
        }

        for index in prepared.indices {
            let attachment = prepared[index]
            switch attachment.kind {
            case .image:
                let dataURL = try imageDataURL(for: attachment)
                prepared[index] = attachment.withWirePayloads(imageDataURL: dataURL)
                parts.append(.imageURL(dataURL))
            case .video:
                let dataURL = try videoDataURL(for: attachment)
                prepared[index] = attachment.withWirePayloads(videoDataURL: dataURL)
                parts.append(.videoURL(dataURL))
            case .file, .audio:
                break
            }
        }

        let visualPartCount = parts.filter { $0.type == "image_url" || $0.type == "video_url" }.count
        let expectedVisualCount = attachments.filter { $0.kind == .image || $0.kind == .video }.count
        guard visualPartCount == expectedVisualCount else {
            throw ChatAttachmentError.visualEncodingFailed(filename: "attachment")
        }

        guard !parts.isEmpty else {
            throw ChatAttachmentError.visualEncodingFailed(filename: "attachment")
        }

        return prepared
    }

    static func makeContentParts(
        modelText: String,
        attachments: [ChatMessageAttachment]
    ) throws -> [ProviderChatContentPart]? {
        if hasPersistedVisualWire(attachments) {
            return try makeContentPartsFromPersisted(modelText: modelText, attachments: attachments)
        }
        guard hasVisualMedia(attachments) else { return nil }

        var parts: [ProviderChatContentPart] = []
        let trimmedModelText = modelText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedModelText.isEmpty {
            parts.append(.text(trimmedModelText))
        }

        for attachment in attachments where attachment.kind == .image {
            let dataURL = try imageDataURL(for: attachment)
            parts.append(.imageURL(dataURL))
        }

        for attachment in attachments where attachment.kind == .video {
            let dataURL = try videoDataURL(for: attachment)
            parts.append(.videoURL(dataURL))
        }

        let visualPartCount = parts.filter { $0.type == "image_url" || $0.type == "video_url" }.count
        let expectedVisualCount = attachments.filter { $0.kind == .image || $0.kind == .video }.count
        guard visualPartCount == expectedVisualCount else {
            throw ChatAttachmentError.visualEncodingFailed(filename: "attachment")
        }

        return parts.isEmpty ? nil : parts
    }

    static func makeContentPartsFromPersisted(
        modelText: String,
        attachments: [ChatMessageAttachment]
    ) throws -> [ProviderChatContentPart]? {
        guard hasVisualMedia(attachments) else { return nil }

        var parts: [ProviderChatContentPart] = []
        let trimmedModelText = modelText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedModelText.isEmpty {
            parts.append(.text(trimmedModelText))
        }

        for attachment in attachments where attachment.kind == .image {
            guard let dataURL = attachment.wireImageDataURL else {
                throw ChatAttachmentError.visualEncodingFailed(filename: attachment.filename)
            }
            parts.append(.imageURL(dataURL))
        }

        for attachment in attachments where attachment.kind == .video {
            guard let dataURL = attachment.wireVideoDataURL else {
                throw ChatAttachmentError.visualEncodingFailed(filename: attachment.filename)
            }
            parts.append(.videoURL(dataURL))
        }

        return parts.isEmpty ? nil : parts
    }

    static func estimatedWireTokenOverhead(for attachments: [ChatMessageAttachment]) -> Int {
        attachments.reduce(0) { partial, attachment in
            let payloadLength: Int
            switch attachment.kind {
            case .image:
                payloadLength = attachment.wireImageDataURL?.count
                    ?? fileByteCount(at: attachment.localPath) * 4 / 3
            case .video:
                payloadLength = attachment.wireVideoDataURL?.count
                    ?? fileByteCount(at: attachment.localPath) * 4 / 3
            case .file, .audio:
                payloadLength = 0
            }
            return partial + max((payloadLength + 3) / 4, 0)
        }
    }

    private static func imageDataURL(for attachment: ChatMessageAttachment) throws -> String {
        if let wireImageDataURL = attachment.wireImageDataURL {
            return wireImageDataURL
        }
        guard let dataURL = ChatMultimodalImagePayloadLogic.dataURL(fromFileAt: attachment.localPath) else {
            throw ChatAttachmentError.visualEncodingFailed(filename: attachment.filename)
        }
        return dataURL
    }

    private static func videoDataURL(for attachment: ChatMessageAttachment) throws -> String {
        if let wireVideoDataURL = attachment.wireVideoDataURL {
            return wireVideoDataURL
        }
        let byteCount = fileByteCount(at: attachment.localPath)
        try ChatAttachmentSizeLimits.validateVideoWireSize(byteCount: byteCount)
        guard let dataURL = ChatMultimodalVideoPayloadLogic.dataURL(fromFileAt: attachment.localPath) else {
            throw ChatAttachmentError.visualEncodingFailed(filename: attachment.filename)
        }
        return dataURL
    }

    private static func fileByteCount(at localPath: String) -> Int {
        (try? FileManager.default.attributesOfItem(atPath: localPath)[.size] as? NSNumber)?.intValue ?? 0
    }
}
