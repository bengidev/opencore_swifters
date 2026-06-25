import Foundation

/// Streaming proxy: resolves a provider adapter from the registry and delegates
/// request encoding and SSE mapping to the adapter implementation.
nonisolated struct ChatOpenAICompatibleStreamingClient: Sendable {
    let credentialStore: any CredentialStoring
    let urlSession: URLSession

    init(
        credentialStore: any CredentialStoring,
        urlSession: URLSession = .shared
    ) {
        self.credentialStore = credentialStore
        self.urlSession = urlSession
    }

    nonisolated func stream(request: ChatRequest) -> AsyncStream<ChatStreamingEvent> {
        let credentialStore = self.credentialStore
        let urlSession = self.urlSession

        return AsyncStream { continuation in
            let task = Task {
                do {
                    let adapter = ProviderRegistry.resolve(id: request.providerID)
                    guard let secret = credentialStore.secret(for: adapter.descriptor.id) else {
                        continuation.yield(.error("Missing API key. Add your provider key to continue."))
                        continuation.finish()
                        return
                    }

                    let urlRequest = try adapter.makeChatCompletionURLRequest(
                        secret: secret,
                        chatRequest: request
                    )

                    let (bytes, response) = try await urlSession.bytes(for: urlRequest)

                    if let httpResponse = response as? HTTPURLResponse,
                       !(200...299).contains(httpResponse.statusCode) {
                        let message = await Self.errorMessage(
                            forStatus: httpResponse.statusCode,
                            bytes: bytes
                        )
                        continuation.yield(.error(ChatStreamError(message: message)))
                        continuation.finish()
                        return
                    }

                    var decoder = ChatSSEDecoder()
                    var didEmitDone = false

                    for try await line in bytes.lines {
                        guard let lineData = (line + "\n").data(using: .utf8) else { continue }
                        for event in decoder.append(lineData) {
                            switch event {
                            case .done:
                                continuation.yield(.done)
                                didEmitDone = true
                            case let .data(payload):
                                if let mapped = ProviderOpenAICompatibleAdapter.mapStreamPayload(payload) {
                                    for chatEvent in mapped {
                                        continuation.yield(chatEvent)
                                        if case .error = chatEvent { didEmitDone = true }
                                    }
                                }
                            }
                        }
                        if didEmitDone { break }
                    }

                    if !didEmitDone {
                        continuation.yield(.done)
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.yield(.error(ChatStreamError(message: error.localizedDescription)))
                    continuation.finish()
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    static func makeURLRequest(
        providerID: String,
        secret: String,
        chatRequest: ChatRequest
    ) throws -> URLRequest {
        let adapter = ProviderRegistry.resolve(id: providerID)
        return try adapter.makeChatCompletionURLRequest(secret: secret, chatRequest: chatRequest)
    }

    static func errorMessage(forStatus status: Int, bytes: URLSession.AsyncBytes) async -> String {
        var body = Data()
        var iterator = bytes.makeAsyncIterator()
        while body.count < 64 * 1024, let byte = try? await iterator.next() {
            body.append(byte)
        }

        if status == 401 {
            return "Unauthorized (401). Check that your API key is valid."
        }

        if status == 403 {
            if let providerMessage = ProviderOpenAICompatibleAdapter.decodeErrorBody(body) {
                return "Forbidden (403): \(providerMessage)"
            }
            return "Forbidden (403). Your plan may not include API access. Upgrade your provider plan to use these endpoints."
        }

        if let providerMessage = ProviderOpenAICompatibleAdapter.decodeErrorBody(body) {
            return "Request failed (\(status)): \(providerMessage)"
        }
        return "Request failed with status \(status)."
    }
}
