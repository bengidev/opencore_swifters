import Foundation

/// Closure-based streaming boundary for chat API access.
nonisolated struct ChatStreamingClient: Sendable {
    var stream: @Sendable (ChatRequest) -> AsyncStream<ChatStreamingEvent>

    init(stream: @escaping @Sendable (ChatRequest) -> AsyncStream<ChatStreamingEvent>) {
        self.stream = stream
    }

    static let preview = ChatStreamingClient { _ in
        AsyncStream { $0.finish() }
    }

    static func live(credentialStore: any CredentialStoring) -> ChatStreamingClient {
        let client = ChatOpenAICompatibleStreamingClient(credentialStore: credentialStore)
        return ChatStreamingClient(stream: client.stream(request:))
    }
}
