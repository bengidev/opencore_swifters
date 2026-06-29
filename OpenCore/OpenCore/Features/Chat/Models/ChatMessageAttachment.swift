import Foundation

nonisolated enum ChatMessageAttachmentKind: String, Codable, Sendable, Equatable {
    case image
    case video
    case file
    case audio
}

/// Persisted attachment shown in the user bubble. Model-facing text lives on the parent message.
nonisolated struct ChatMessageAttachment: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    let kind: ChatMessageAttachmentKind
    let filename: String
    /// Absolute path to the copied attachment in app storage.
    let localPath: String
    let thumbnailJPEGData: Data?
    let waveformSamples: [Float]
    let audioDuration: TimeInterval
    /// Speech transcript used only for model input; never shown in the bubble.
    let speechTranscript: String?
    /// UTF-8 text extracted from plain-text file attachments for model input.
    let fileTextContent: String?
    /// Base64 data URL persisted at send time so history requests do not re-encode from disk.
    let wireImageDataURL: String?
    let wireVideoDataURL: String?

    init(
        id: UUID = UUID(),
        kind: ChatMessageAttachmentKind,
        filename: String,
        localPath: String,
        thumbnailJPEGData: Data? = nil,
        waveformSamples: [Float] = [],
        audioDuration: TimeInterval = 0,
        speechTranscript: String? = nil,
        fileTextContent: String? = nil,
        wireImageDataURL: String? = nil,
        wireVideoDataURL: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.filename = filename
        self.localPath = localPath
        self.thumbnailJPEGData = thumbnailJPEGData
        self.waveformSamples = waveformSamples
        self.audioDuration = audioDuration
        self.speechTranscript = speechTranscript
        self.fileTextContent = fileTextContent
        self.wireImageDataURL = wireImageDataURL
        self.wireVideoDataURL = wireVideoDataURL
    }
}

struct ChatTextMessageDetail: Codable, Equatable, Sendable {
    var attachments: [ChatMessageAttachment]
    var modelContent: String?
}

extension ChatMessageAttachment {
    var fileURL: URL {
        URL(fileURLWithPath: localPath)
    }

    nonisolated func withWirePayloads(imageDataURL: String? = nil, videoDataURL: String? = nil) -> ChatMessageAttachment {
        ChatMessageAttachment(
            id: id,
            kind: kind,
            filename: filename,
            localPath: localPath,
            thumbnailJPEGData: thumbnailJPEGData,
            waveformSamples: waveformSamples,
            audioDuration: audioDuration,
            speechTranscript: speechTranscript,
            fileTextContent: fileTextContent,
            wireImageDataURL: imageDataURL ?? wireImageDataURL,
            wireVideoDataURL: videoDataURL ?? wireVideoDataURL
        )
    }
}
