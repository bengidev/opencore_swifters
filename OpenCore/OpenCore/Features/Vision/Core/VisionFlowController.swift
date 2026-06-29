import Foundation
import Observation
import UniformTypeIdentifiers

/// Owns composer media attachment intake — copies files into durable storage for send.
@MainActor
@Observable
final class VisionFlowController {
    private(set) var state = VisionFlowState()
    private let thumbnailBuilder: @Sendable (Data) -> Data?

    init(thumbnailBuilder: @escaping @Sendable (Data) -> Data? = VisionAttachmentThumbnailLogic.jpegThumbnail(from:)) {
        self.thumbnailBuilder = thumbnailBuilder
    }

    func clearError() {
        state.errorMessage = nil
    }

    func dismissProcessingPresentation() {
        state.isProcessing = false
        state.statusMessage = nil
    }

    func attachFile(at url: URL) async -> ChatMessageAttachment? {
        clearError()

        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let filename = url.lastPathComponent
        let kind = ChatModelInputBuilder.attachmentKind(
            filename: filename,
            contentType: UTType(filenameExtension: url.pathExtension)
        )

        return await performAttach(
            filename: filename,
            kind: kind,
            dataLoader: { try Data(contentsOf: url) }
        )
    }

    func attachImportedData(
        _ data: Data,
        filename: String,
        contentType: UTType?
    ) async -> ChatMessageAttachment? {
        clearError()

        let kind = ChatModelInputBuilder.attachmentKind(
            filename: filename,
            contentType: contentType
        )

        return await performAttach(
            filename: filename,
            kind: kind,
            dataLoader: { data }
        )
    }

    private func performAttach(
        filename: String,
        kind: ChatMessageAttachmentKind,
        dataLoader: () throws -> Data
    ) async -> ChatMessageAttachment? {
        state.isProcessing = true
        state.statusMessage = VisionProcessingDisplayLogic.statusMessage(for: visionKind(from: kind))
        defer {
            state.isProcessing = false
            state.statusMessage = nil
        }

        do {
            let data = try dataLoader()
            try ChatAttachmentSizeLimits.validateImportSize(byteCount: data.count)
            if kind == .video {
                try ChatAttachmentSizeLimits.validateVideoWireSize(byteCount: data.count)
            }

            let fileTextContent: String?
            if kind == .file {
                fileTextContent = try ChatPlainTextFileReader.read(from: data)
            } else {
                fileTextContent = nil
            }

            let storedURL = try ChatAttachmentStore.save(data: data, suggestedFilename: filename)
            let thumbnail = kind == .image ? thumbnailBuilder(data) : nil
            return ChatMessageAttachment(
                kind: kind,
                filename: filename,
                localPath: storedURL.path,
                thumbnailJPEGData: thumbnail,
                fileTextContent: fileTextContent
            )
        } catch {
            state.errorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            return nil
        }
    }

    private func visionKind(from kind: ChatMessageAttachmentKind) -> VisionMediaKind {
        switch kind {
        case .image:
            return .image
        case .video:
            return .video
        case .file:
            return .plainText
        case .audio:
            return .unsupported
        }
    }
}
