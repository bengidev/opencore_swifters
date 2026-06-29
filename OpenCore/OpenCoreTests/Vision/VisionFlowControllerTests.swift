import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import OpenCore

@Suite("Vision Flow Controller", .serialized)
@MainActor
struct VisionFlowControllerTests {
    @Test("starts idle without processing state")
    func startsIdle() {
        let controller = VisionFlowController()

        #expect(controller.state.isProcessing == false)
        #expect(controller.state.statusMessage == nil)
        #expect(controller.state.errorMessage == nil)
    }

    @Test("attachImportedData stores an image attachment")
    func attachesImageData() async throws {
        let pngData = try makeSolidPNGData()
        let controller = VisionFlowController()

        let attachment = await controller.attachImportedData(
            pngData,
            filename: "scan.png",
            contentType: .png
        )

        #expect(attachment?.kind == .image)
        #expect(attachment?.filename == "scan.png")
        #expect(attachment?.thumbnailJPEGData != nil)
        #expect(FileManager.default.fileExists(atPath: attachment?.localPath ?? ""))
        if let localPath = attachment?.localPath {
            ChatAttachmentStore.remove(at: localPath)
        }
    }

    @Test("attachImportedData stores file text content for plain text files")
    func attachesPlainTextFile() async throws {
        let data = Data("console.log('hi')".utf8)
        let controller = VisionFlowController()

        let attachment = await controller.attachImportedData(
            data,
            filename: "script.js",
            contentType: .plainText
        )

        #expect(attachment?.kind == .file)
        #expect(attachment?.fileTextContent == "console.log('hi')")
        if let localPath = attachment?.localPath {
            ChatAttachmentStore.remove(at: localPath)
        }
    }

    private func makeSolidPNGData() throws -> Data {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        defer { try? FileManager.default.removeItem(at: url) }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: 8,
            height: 8,
            bitsPerComponent: 8,
            bytesPerRow: 32,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let image = context.makeImage() else {
            throw NSError(domain: "VisionFlowControllerTests", code: 1)
        }

        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw NSError(domain: "VisionFlowControllerTests", code: 2)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "VisionFlowControllerTests", code: 3)
        }
        return try Data(contentsOf: url)
    }
}
