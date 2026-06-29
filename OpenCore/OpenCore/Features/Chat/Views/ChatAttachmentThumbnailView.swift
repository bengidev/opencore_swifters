import SwiftUI
import UIKit

struct ChatAttachmentThumbnailView: View {
    let thumbnailJPEGData: Data?
    let localPath: String?
    let side: CGFloat
    let cornerRadius: CGFloat
    let fallbackSystemImage: String

    @Environment(\.sharedPalette) private var palette

    init(
        thumbnailJPEGData: Data?,
        localPath: String? = nil,
        side: CGFloat = 72,
        cornerRadius: CGFloat = 12,
        fallbackSystemImage: String = "photo"
    ) {
        self.thumbnailJPEGData = thumbnailJPEGData
        self.localPath = localPath
        self.side = side
        self.cornerRadius = cornerRadius
        self.fallbackSystemImage = fallbackSystemImage
    }

    var body: some View {
        Group {
            if let image = resolvedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(palette.surfaceSubtle.opacity(palette.isDark ? 0.55 : 0.85))
                    .overlay {
                        Image(systemName: fallbackSystemImage)
                            .foregroundStyle(palette.textTertiary)
                    }
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(palette.lineSoft.opacity(0.8), lineWidth: 1)
        }
    }

    private var resolvedImage: UIImage? {
        if let thumbnailJPEGData, let image = UIImage(data: thumbnailJPEGData) {
            return image
        }
        if let localPath, let image = UIImage(contentsOfFile: localPath) {
            return image
        }
        return nil
    }
}
