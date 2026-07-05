import Foundation

nonisolated enum ChatMermaidJSEscaping: Sendable {
    /// Returns a JSON-encoded string literal safe for embedding in `evaluateJavaScript` calls.
    static func quotedJavaScriptString(_ source: String) -> String {
        guard let data = try? JSONEncoder().encode(source),
              var json = String(data: data, encoding: .utf8),
              json.hasPrefix("\""), json.hasSuffix("\"") else {
            return "\"\""
        }
        let inner = String(json.dropFirst().dropLast())
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
        return "\"\(inner)\""
    }
}
