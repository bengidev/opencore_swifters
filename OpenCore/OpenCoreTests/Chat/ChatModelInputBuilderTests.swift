import Foundation
import Testing

@testable import OpenCore

@Suite("Chat Model Input Builder")
struct ChatModelInputBuilderTests {
    @Test("includes file content and visible text for the provider")
    func buildsModelContent() {
        let attachment = ChatMessageAttachment(
            kind: .file,
            filename: "note.txt",
            localPath: "/tmp/note.txt",
            fileTextContent: "file body"
        )

        let modelContent = ChatModelInputBuilder.modelContent(
            visibleText: "What is this?",
            attachments: [attachment]
        )

        #expect(modelContent.contains("[Attached file: note.txt]"))
        #expect(modelContent.contains("file body"))
        #expect(!modelContent.contains("/tmp/note.txt"))
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
