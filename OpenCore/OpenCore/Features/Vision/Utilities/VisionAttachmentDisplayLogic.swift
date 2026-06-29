import Foundation

/// Pure display rules for composer attachment indicators.
nonisolated enum VisionAttachmentDisplayLogic: Sendable {
    static let thumbnailSide: CGFloat = 72
    static let thumbnailCornerRadius: CGFloat = 12
    static let pillCornerRadius: CGFloat = 14

    static func systemImage(for kind: VisionMediaKind) -> String {
        switch kind {
        case .plainText:
            return "doc.text"
        case .image:
            return "photo"
        case .video:
            return "film"
        case .unsupported:
            return "questionmark"
        }
    }

    static func showsPill(for kind: VisionMediaKind) -> Bool {
        kind != .image
    }
}
