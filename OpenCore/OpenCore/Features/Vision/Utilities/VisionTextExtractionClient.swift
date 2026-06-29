import Foundation

struct VisionExtractionRequest: Sendable {
    let kind: VisionMediaKind
    let data: Data
    let fileURL: URL?
}

/// Closure-based boundary for media-to-text extraction (strategy dispatch behind one seam).
nonisolated struct VisionTextExtractionClient: Sendable {
    var extract: @Sendable (VisionExtractionRequest) async throws -> String

    init(extract: @escaping @Sendable (VisionExtractionRequest) async throws -> String) {
        self.extract = extract
    }

    static let preview = VisionTextExtractionClient { _ in
        ""
    }

    static func live() -> VisionTextExtractionClient {
        VisionTextExtractionClient { request in
            switch request.kind {
            case .plainText:
                return try VisionPlainTextExtractor.extract(from: request.data)
            case .image:
                return try await VisionImageTextExtractor.extract(from: request.data)
            case .video:
                guard let fileURL = request.fileURL else {
                    throw VisionExtractionError.unreadableContent
                }
                return try await VisionVideoTextExtractor.extract(from: fileURL)
            case .unsupported:
                throw VisionExtractionError.unsupportedMedia
            }
        }
    }
}
