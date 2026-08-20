import Foundation
import Testing
import UIKit

@testable import OpenCore

@Suite("Chat Multimodal Wire Logic")
struct ChatMultimodalWireLogicTests {
    @Test("builds text-first OpenRouter content parts for images")
    func buildsImageContentParts() throws {
        let imagePath = try writeTemporaryJPEG()
        defer { try? FileManager.default.removeItem(atPath: imagePath) }

        let attachment = ChatMessageAttachment(
            kind: .image,
            filename: "photo.jpg",
            localPath: imagePath
        )

        let parts = try ChatMultimodalWireLogic.makeContentParts(
            modelText: "What is this?",
            attachments: [attachment]
        )

        #expect(parts?.count == 2)
        #expect(parts?.first?.type == "text")
        #expect(parts?.first?.text == "What is this?")
        #expect(parts?.last?.type == "image_url")
        #expect(parts?.last?.imageURL?.url.hasPrefix("data:image/jpeg;base64,") == true)
    }

    @Test("builds video_url parts after text")
    func buildsVideoContentParts() throws {
        let videoPath = try writeTemporaryFile(named: "clip.mp4", data: Data("fake-video".utf8))
        defer { try? FileManager.default.removeItem(atPath: videoPath) }

        let attachment = ChatMessageAttachment(
            kind: .video,
            filename: "clip.mp4",
            localPath: videoPath
        )

        let parts = try ChatMultimodalWireLogic.makeContentParts(
            modelText: "Describe this clip",
            attachments: [attachment]
        )

        #expect(parts?.count == 2)
        #expect(parts?.first?.type == "text")
        #expect(parts?.last?.type == "video_url")
        #expect(parts?.last?.videoURL?.url.hasPrefix("data:video/mp4;base64,") == true)
    }

    @Test("returns nil when there is no visual media")
    func skipsPlainTextAttachments() throws {
        let attachment = ChatMessageAttachment(
            kind: .file,
            filename: "note.txt",
            localPath: "/tmp/note.txt",
            fileTextContent: "hello"
        )

        let parts = try ChatMultimodalWireLogic.makeContentParts(
            modelText: "Read this",
            attachments: [attachment]
        )

        #expect(parts == nil)
    }

    @Test("persists wire payloads at send time")
    func persistsWirePayloads() throws {
        let imagePath = try writeTemporaryJPEG()
        defer { try? FileManager.default.removeItem(atPath: imagePath) }

        let attachment = ChatMessageAttachment(
            kind: .image,
            filename: "photo.jpg",
            localPath: imagePath
        )

        let prepared = try ChatMultimodalWireLogic.prepareAttachmentsForSend(
            attachments: [attachment],
            modelText: "Look"
        )

        #expect(prepared.first?.wireImageDataURL?.hasPrefix("data:image/jpeg;base64,") == true)

        let parts = try ChatMultimodalWireLogic.makeContentParts(
            modelText: "Look",
            attachments: prepared
        )
        #expect(parts?.count == 2)
    }

    @Test("throws when image encoding fails")
    func throwsOnMissingImageFile() {
        let attachment = ChatMessageAttachment(
            kind: .image,
            filename: "missing.jpg",
            localPath: "/tmp/does-not-exist-\(UUID().uuidString).jpg"
        )

        #expect(throws: ChatAttachmentError.self) {
            try ChatMultimodalWireLogic.makeContentParts(
                modelText: "",
                attachments: [attachment]
            )
        }
    }

    @Test("request building degrades to text instead of dropping a stale image")
    func requestBuildingDegradesForStaleImage() throws {
        let attachment = ChatMessageAttachment(
            kind: .image,
            filename: "missing.jpg",
            localPath: "/tmp/does-not-exist-\(UUID().uuidString).jpg"
        )
        let message = ChatMessage.text(
            role: .user,
            content: "Can you analyze this?",
            attachments: [attachment]
        )

        // A stale attachment in history must not abort the whole request; it
        // degrades to text-only so the rest of the conversation still sends.
        let request = try ChatOpenAICompatibleStreamingClient.makeURLRequest(
            providerID: ProviderDescriptor.openRouter.id,
            secret: "test-key",
            chatRequest: ChatRequest(
                conversationID: UUID(),
                messages: [message],
                providerID: ProviderDescriptor.openRouter.id,
                modelID: "openrouter/free"
            )
        )
        let body = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any]
        let messages = body?["messages"] as? [[String: Any]]
        let content = messages?.first?["content"] as? String
        #expect(content == "Can you analyze this?")
    }

    @Test("historical messages preserve valid visuals while dropping stale visuals")
    func historicalMessageDropsOnlyStaleVisual() throws {
        let valid = ChatMessageAttachment(
            kind: .image,
            filename: "valid.jpg",
            localPath: "/tmp/missing-valid.jpg",
            wireImageDataURL: "data:image/jpeg;base64,AAAA"
        )
        let stale = ChatMessageAttachment(
            kind: .image,
            filename: "stale.jpg",
            localPath: "/tmp/does-not-exist-\(UUID().uuidString).jpg"
        )

        let content = try ProviderOpenAICompatibleAdapter.wireMessageContent(
            for: ChatTextMessage(
                role: .user,
                content: "Analyze these",
                attachments: [valid, stale]
            )
        )

        guard case let .parts(parts) = content else {
            Issue.record("Expected multimodal parts")
            return
        }
        #expect(parts.count == 2)
        #expect(parts.filter { $0.type == "image_url" }.count == 1)
    }

    @Test("fresh send with unreadable image still surfaces an error before request")
    func freshSendFailsForInvalidImage() {
        let attachment = ChatMessageAttachment(
            kind: .image,
            filename: "missing.jpg",
            localPath: "/tmp/does-not-exist-\(UUID().uuidString).jpg"
        )

        // The fresh-send path validates attachments up front and throws there,
        // so the user sees the error before the request is built.
        #expect(throws: ChatAttachmentError.self) {
            _ = try ChatMultimodalWireLogic.prepareAttachmentsForSend(
                attachments: [attachment],
                modelText: "Can you analyze this?"
            )
        }
    }

    private func writeTemporaryJPEG() throws -> String {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24))
        let imageData = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }.jpegData(compressionQuality: 0.9) ?? Data()
        return try writeTemporaryFile(named: "photo.jpg", data: imageData)
    }

    private func writeTemporaryFile(named filename: String, data: Data) throws -> String {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)-\(filename)")
        try data.write(to: url)
        return url.path
    }
}
