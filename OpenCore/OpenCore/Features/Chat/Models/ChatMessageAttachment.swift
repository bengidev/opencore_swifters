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

    init(
        id: UUID = UUID(),
        kind: ChatMessageAttachmentKind,
        filename: String,
        localPath: String,
        thumbnailJPEGData: Data? = nil,
        waveformSamples: [Float] = [],
        audioDuration: TimeInterval = 0,
        speechTranscript: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.filename = filename
        self.localPath = localPath
        self.thumbnailJPEGData = thumbnailJPEGData
        self.waveformSamples = waveformSamples
        self.audioDuration = audioDuration
        self.speechTranscript = speechTranscript
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
}
