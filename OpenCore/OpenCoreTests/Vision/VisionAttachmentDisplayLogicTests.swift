import Foundation
import Testing

@testable import OpenCore

@Suite("Vision Attachment Display Logic")
struct VisionAttachmentDisplayLogicTests {
    @Test("maps media kinds to attachment icons")
    func systemImages() {
        #expect(VisionAttachmentDisplayLogic.systemImage(for: .plainText) == "doc.text")
        #expect(VisionAttachmentDisplayLogic.systemImage(for: .image) == "photo")
        #expect(VisionAttachmentDisplayLogic.systemImage(for: .video) == "film")
    }

    @Test("uses pill labels for non-image attachments")
    func pillLabels() {
        #expect(VisionAttachmentDisplayLogic.showsPill(for: .plainText) == true)
        #expect(VisionAttachmentDisplayLogic.showsPill(for: .video) == true)
        #expect(VisionAttachmentDisplayLogic.showsPill(for: .image) == false)
    }
}
