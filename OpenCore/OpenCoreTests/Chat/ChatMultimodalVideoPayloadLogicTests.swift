import Foundation
import Testing

@testable import OpenCore

@Suite("Chat Multimodal Video Payload Logic")
struct ChatMultimodalVideoPayloadLogicTests {
    @Test("maps common extensions to OpenRouter video MIME types")
    func mapsVideoMimeTypes() {
        #expect(ChatMultimodalVideoPayloadLogic.mimeType(forFilename: "clip.mp4") == "video/mp4")
        #expect(ChatMultimodalVideoPayloadLogic.mimeType(forFilename: "clip.mov") == "video/mov")
        #expect(ChatMultimodalVideoPayloadLogic.mimeType(forFilename: "clip.webm") == "video/webm")
        #expect(ChatMultimodalVideoPayloadLogic.mimeType(forFilename: "clip.mpeg") == "video/mpeg")
    }
}
