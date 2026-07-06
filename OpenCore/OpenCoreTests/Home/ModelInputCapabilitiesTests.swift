import Foundation
import Testing

@testable import OpenCore

@Suite("Model Input Capabilities")
struct ModelInputCapabilitiesTests {
    @Test("text-only model does not support attachments")
    func textOnly() {
        let caps = ModelInputCapabilities(inputModalities: [.text])
        #expect(!caps.supportsAttachments)
        #expect(!caps.supportsFileInput)
        #expect(!caps.supportsImageInput)
    }

    @Test("image modality enables attachments and image input")
    func imageModality() {
        let caps = ModelInputCapabilities(inputModalities: [.text, .image])
        #expect(caps.supportsAttachments)
        #expect(caps.supportsImageInput)
        #expect(!caps.supportsFileInput)
    }

    @Test("derives capabilities from ChatModel booleans")
    func fromChatModel() {
        let model = ChatModel(
            id: "openai/gpt-4o",
            displayName: "GPT-4o",
            supportsFileInput: true,
            supportsImageInput: true,
            supportsVideoInput: false,
            supportsAudioInput: false
        )
        let caps = ModelInputCapabilities.from(model)
        #expect(caps.supportsAttachments)
        #expect(caps.supportsFileInput)
        #expect(caps.supportsImageInput)
    }
}
