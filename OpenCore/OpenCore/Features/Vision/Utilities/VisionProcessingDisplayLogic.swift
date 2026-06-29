import Foundation

/// User-facing status copy while vision extraction runs.
nonisolated enum VisionProcessingDisplayLogic: Sendable {
    static func statusMessage(for kind: VisionMediaKind) -> String {
        switch kind {
        case .plainText:
            return "Reading file…"
        case .image:
            return "Scanning image…"
        case .video:
            return "Scanning video…"
        case .unsupported:
            return "Processing…"
        }
    }
}
