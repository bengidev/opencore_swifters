import Foundation

/// Supported media categories for composer text extraction.
nonisolated enum VisionMediaKind: Equatable, Sendable {
    case plainText
    case image
    case video
    case unsupported
}
