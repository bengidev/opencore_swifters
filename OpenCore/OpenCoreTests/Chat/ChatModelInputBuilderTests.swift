import Foundation
import Testing

@testable import OpenCore

@Suite("Chat Model Input Builder")
struct ChatModelInputBuilderTests {
    @Test("includes file paths and visible text for the provider")
    func buildsModelContent() {
        let attachment = ChatMessageAttachment(
            kind: .image,
            filename: "scan.png",
            localPath: "/tmp/scan.png"
        )

        let modelContent = ChatModelInputBuilder.modelContent(
            visibleText: "What is this?",
            attachments: [attachment]
        )

        #expect(!modelContent.contains("[Attached files]"))
        #expect(!modelContent.contains("/tmp/scan.png"))
        #expect(modelContent.contains("What is this?"))
    }

    @Test("classifies video attachments separately from files")
    func classifiesVideoAttachments() {
        let kind = ChatModelInputBuilder.attachmentKind(
            filename: "clip.mp4",
            contentType: nil
        )

        #expect(kind == .video)
    }

    @Test("includes hidden speech transcript for audio attachments")
    func includesSpeechTranscript() {
        let attachment = ChatMessageAttachment(
            kind: .audio,
            filename: "Voice note",
            localPath: "/tmp/voice.caf",
            speechTranscript: "Hello there"
        )

        let modelContent = ChatModelInputBuilder.modelContent(
            visibleText: "",
            attachments: [attachment]
        )

        #expect(modelContent.contains("[Voice transcript]"))
        #expect(modelContent.contains("Hello there"))
        #expect(modelContent.contains("/tmp/voice.caf") == false)
    }
}
