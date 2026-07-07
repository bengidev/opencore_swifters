import Foundation
import Testing
import UIKit

@testable import OpenCore

@Suite("Provider OpenAI Compatible Multimodal Wire")
struct ProviderOpenAICompatibleMultimodalWireTests {
    @Test("encodes image attachments as multimodal message content")
    func encodesMultimodalUserMessage() throws {
        let imagePath = try writeTemporaryJPEG()
        defer { try? FileManager.default.removeItem(atPath: imagePath) }

        let message = ChatMessage.text(
            id: UUID(),
            role: .user,
            content: "What is this?",
            timestamp: .init(),
            attachments: [
                ChatMessageAttachment(
                    kind: .image,
                    filename: "photo.jpg",
                    localPath: imagePath
                )
            ]
        )

        let body = try ProviderOpenAICompatibleAdapter.makeRequestBody(
            chatRequest: ChatRequest(
                conversationID: UUID(),
                messages: [message],
                providerID: "openrouter",
                modelID: "openai/gpt-4o"
            ),
            reasoningWireStyle: .topLevelEffort,
            supportsProviderRouting: true
        )

        let encoded = try JSONEncoder().encode(body)
        let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        let messages = json?["messages"] as? [[String: Any]]
        let content = messages?.first?["content"] as? [[String: Any]]

        #expect(content?.count == 2)
        #expect(content?.first?["type"] as? String == "text")
        #expect(content?.first?["text"] as? String == "What is this?")
        #expect(content?.last?["type"] as? String == "image_url")
        let imageURL = content?.last?["image_url"] as? [String: Any]
        #expect((imageURL?["url"] as? String)?.hasPrefix("data:image/jpeg;base64,") == true)
    }

    private func writeTemporaryJPEG() throws -> String {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24))
        let imageData = renderer.image { context in
            UIColor.green.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }.jpegData(compressionQuality: 0.9) ?? Data()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("wire-photo.jpg")
        try imageData.write(to: url)
        return url.path
    }
}
