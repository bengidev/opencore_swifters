import Foundation
import UIKit

/// Builds lightweight JPEG thumbnails for image attachment indicators.
nonisolated enum VisionAttachmentThumbnailLogic: Sendable {
    static let maxPixelDimension: CGFloat = 120
    static let compressionQuality: CGFloat = 0.72

    static func jpegThumbnail(from imageData: Data) -> Data? {
        guard let image = UIImage(data: imageData) else { return nil }

        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > 0 else { return nil }

        let scale = min(maxPixelDimension / longestSide, 1)
        let targetSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let thumbnail = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return thumbnail.jpegData(compressionQuality: compressionQuality)
    }
}
