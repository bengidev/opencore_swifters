import Foundation

nonisolated enum ChatAssistantMarkdownLinkPolicy: Sendable {
    private static let allowedSchemes: Set<String> = ["https", "http", "mailto"]

    static func isAllowed(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return allowedSchemes.contains(scheme)
    }
}
