import Foundation
import Testing

@testable import OpenCore

@Suite("Home Composer Model Capability Logic")
struct HomeComposerModelCapabilityLogicTests {
    @Test("detects image and video attachments in draft")
    func detectsVisualAttachments() {
        let attachments = [
            ChatMessageAttachment(kind: .file, filename: "note.txt", localPath: "/tmp/note.txt"),
            ChatMessageAttachment(kind: .image, filename: "scan.png", localPath: "/tmp/scan.png"),
            ChatMessageAttachment(kind: .video, filename: "clip.mp4", localPath: "/tmp/clip.mp4")
        ]

        #expect(HomeComposerModelCapabilityLogic.hasImageAttachments(attachments))
        #expect(HomeComposerModelCapabilityLogic.hasVideoAttachments(attachments))
    }

    @Test("flags unsupported visual attachments for the selected model")
    func flagsUnsupportedVisualAttachments() {
        let textModel = ChatModel(id: "llama", displayName: "Llama")
        let attachments = [
            ChatMessageAttachment(kind: .image, filename: "scan.png", localPath: "/tmp/scan.png")
        ]

        #expect(
            HomeComposerModelCapabilityLogic.hasUnsupportedVisualAttachments(
                attachments: attachments,
                model: textModel
            )
        )
    }

    @Test("reads image support from the selected model")
    func readsImageSupport() {
        let visionModel = ChatModel(id: "gpt-4o", displayName: "GPT-4o", supportsImageInput: true)
        let textModel = ChatModel(id: "llama", displayName: "Llama", supportsImageInput: false)

        #expect(HomeComposerModelCapabilityLogic.supportsImageInput(for: visionModel))
        #expect(!HomeComposerModelCapabilityLogic.supportsImageInput(for: textModel))
        #expect(!HomeComposerModelCapabilityLogic.supportsImageInput(for: nil))
    }
}
