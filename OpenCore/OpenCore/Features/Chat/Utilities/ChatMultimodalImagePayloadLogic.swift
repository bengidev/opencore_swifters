import Foundation
import UIKit

/// Normalizes local images into OpenRouter-compatible JPEG data URLs.
nonisolated enum ChatMultimodalImagePayloadLogic: Sendable {
    static let maxPayloadDimension: CGFloat = 1_600
    static let compressionQuality: CGFloat = 0.6

    static func dataURL(from imageData: Data) -> String? {
        guard let jpegData = normalizedJPEGData(from: imageData) else { return nil }
        return "data:image/jpeg;base64,\(jpegData.base64EncodedString())"
    }

    static func dataURL(fromFileAt localPath: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: localPath)) else { return nil }
        return dataURL(from: data)
    }

    static func normalizedJPEGData(from sourceData: Data) -> Data? {
        guard let image = UIImage(data: sourceData) else { return nil }

        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }

        let longestSide = max(sourceSize.width, sourceSize.height)
        let scale = min(1, maxPayloadDimension / longestSide)
        let targetSize = CGSize(
            width: floor(sourceSize.width * scale),
            height: floor(sourceSize.height * scale)
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return rendered.jpegData(compressionQuality: compressionQuality)
    }
}
