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

    private func writeTemporaryJPEG() throws -> String {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24))
        let imageData = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }.jpegData(compressionQuality: 0.9) ?? Data()
        return try writeTemporaryFile(named: "photo.jpg", data: imageData)
    }

    private func writeTemporaryFile(named filename: String, data: Data) throws -> String {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url)
        return url.path
    }
}
