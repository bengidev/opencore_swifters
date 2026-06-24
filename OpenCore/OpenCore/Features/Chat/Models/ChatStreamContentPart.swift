import Foundation

nonisolated struct ChatStreamContentPart: Decodable, Sendable, Equatable {
    let type: String?
    let text: String?

    var renderedText: String? {
        guard let text, !text.isEmpty else { return nil }
        switch type {
        case nil, "text", "output_text":
            return text
        default:
            return nil
        }
    }

    static func joinedText(from parts: [ChatStreamContentPart]) -> String {
        parts.compactMap(\.renderedText).joined()
    }
}
