import SwiftUI
import Testing
import UIKit

@testable import OpenCore

@MainActor
@Suite("Chat Attachment Thumbnail View")
struct ChatAttachmentThumbnailViewTests {
    @Test("image thumbnails keep original pixels inside button labels")
    func keepsOriginalPixelsInsideButton() throws {
        let source = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 12, height: 24))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 12, y: 0, width: 12, height: 24))
        }
        let data = try #require(source.jpegData(compressionQuality: 0.95))
        let view = ChatAttachmentThumbnailView(
            thumbnailJPEGData: data,
            side: 48,
            cornerRadius: 0
        )
        .contentShape(Rectangle())
        .onTapGesture {}
        .environment(\.sharedPalette, .resolve(.light))

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let image = try #require(renderer.uiImage)
        let cgImage = try #require(image.cgImage)

        let left = try pixel(in: cgImage, column: 12, row: 24)
        let right = try pixel(in: cgImage, column: 36, row: 24)

        #expect(left.red > left.blue * 2)
        #expect(right.blue > right.red * 2)
    }

    private func pixel(
        in image: CGImage,
        column: Int,
        row: Int
    ) throws -> (red: Int, green: Int, blue: Int) {
        var pixel = [UInt8](repeating: 0, count: 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try #require(CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(
            image,
            in: CGRect(x: -column, y: row - image.height + 1, width: image.width, height: image.height)
        )
        return (Int(pixel[0]), Int(pixel[1]), Int(pixel[2]))
    }
}
