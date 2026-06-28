import Foundation

nonisolated struct ChatStreamContentPart: Decodable, Sendable, Equatable {
    let type: String?
    let text: String?
    let command: ProviderFlexibleCommand?
    let cwd: String?
    let chunk: String?
    let delta: String?
    let output: String?
    let status: String?
    let exitCode: Int?
    let durationMs: Int?

    enum CodingKeys: String, CodingKey {
        case type, text, command, cwd, chunk, delta, output, status
        case exitCode = "exit_code"
        case durationMs = "duration_ms"
    }

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
