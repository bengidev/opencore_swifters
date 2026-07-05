import Foundation
import Testing

@testable import OpenCore

@Suite("Chat Assistant Markdown Link Policy")
struct ChatAssistantMarkdownLinkPolicyTests {
    @Test("Allows https links")
    func httpsAllowed() throws {
        let url = try #require(URL(string: "https://example.com"))
        #expect(ChatAssistantMarkdownLinkPolicy.isAllowed(url))
    }

    @Test("Blocks javascript links")
    func javascriptBlocked() throws {
        let url = try #require(URL(string: "javascript:alert(1)"))
        #expect(!ChatAssistantMarkdownLinkPolicy.isAllowed(url))
    }
}
