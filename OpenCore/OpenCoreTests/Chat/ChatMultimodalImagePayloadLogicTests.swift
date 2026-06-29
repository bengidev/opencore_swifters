import Foundation
import Testing
import UIKit

@testable import OpenCore

@Suite("Chat Multimodal Image Payload Logic")
struct ChatMultimodalImagePayloadLogicTests {
    @Test("normalizes arbitrary image data to JPEG data URLs")
    func normalizesToJPEGDataURL() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 16))
        let pngData = renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 16))
        }.pngData()

        let dataURL = pngData.flatMap(ChatMultimodalImagePayloadLogic.dataURL(from:))

        #expect(dataURL?.hasPrefix("data:image/jpeg;base64,") == true)
    }
}
