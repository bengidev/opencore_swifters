import Foundation

/// OpenAI-compatible streaming chat client parameterized by provider descriptor
/// and credential store. Maps SSE chunks to `ChatStreamingEvent`.
nonisolated struct ChatOpenAICompatibleStreamingClient: Sendable {
    let credentialStore: any SidePanelCredentialStore
    let urlSession: URLSession

    init(
        credentialStore: any SidePanelCredentialStore,
        urlSession: URLSession = .shared
    ) {
        self.credentialStore = credentialStore
        self.urlSession = urlSession
    }

    nonisolated func stream(request: ChatRequest) -> AsyncStream<ChatStreamingEvent> {
        let provider = request.provider
        let credentialStore = self.credentialStore
        let urlSession = self.urlSession

        return AsyncStream { continuation in
            let task = Task {
                do {
                    guard let secret = credentialStore.secret(for: provider.id) else {
                        continuation.yield(.error("Missing API key. Add your provider key to continue."))
                        continuation.finish()
                        return
                    }

                    let urlRequest = try Self.makeURLRequest(
                        provider: provider,
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
                                if let mapped = Self.mapDataPayload(payload) {
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
        provider: SidePanelProviderAPI,
        secret: String,
        chatRequest: ChatRequest
    ) throws -> URLRequest {
        var urlRequest = URLRequest(url: provider.chatCompletionsURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        for (field, value) in provider.defaultHeaders {
            urlRequest.setValue(value, forHTTPHeaderField: field)
        }

        switch provider.authScheme {
        case .bearer:
            urlRequest.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }

        let payload = ChatCompletionsRequestBody(
            model: chatRequest.modelID,
            messages: Self.wireMessages(from: chatRequest.messages),
            stream: true,
            reasoning: chatRequest.reasoningEffort.map {
                ChatCompletionsRequestBody.Reasoning(effort: $0)
            },
            provider: chatRequest.providerSortBy.map {
                ChatCompletionsRequestBody.Provider(sortBy: $0)
            }
        )
        urlRequest.httpBody = try JSONEncoder().encode(payload)
        return urlRequest
    }

    static func wireMessages(from messages: [ChatMessage]) -> [ChatCompletionsRequestBody.Message] {
        messages.compactMap { message in
            switch message {
            case let .text(text):
                return ChatCompletionsRequestBody.Message(
                    role: text.role.rawValue,
                    content: text.content
                )
            case let .system(system):
                return ChatCompletionsRequestBody.Message(
                    role: system.role.rawValue,
                    content: system.content
                )
            case .thinking:
                return nil
            }
        }
    }

    static func mapDataPayload(_ payload: String) -> [ChatStreamingEvent]? {
        guard let data = payload.data(using: .utf8) else { return nil }

        let chunk = try? JSONDecoder().decode(ChatCompletionsStreamChunk.self, from: data)
        guard let chunk else { return nil }

        if let error = chunk.error {
            return [.error(ChatStreamError(message: error.message))]
        }

        var events: [ChatStreamingEvent] = []
        for choice in chunk.choices ?? [] {
            if let reasoning = choice.delta?.reasoningText,
               !reasoning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                events.append(.thinkingDelta(reasoning))
            }
            if let content = choice.delta?.contentText, !content.isEmpty {
                events.append(.textDelta(content))
            }
        }
        return events.isEmpty ? nil : events
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
            if let providerMessage = decodeErrorBody(body) {
                return "Forbidden (403): \(providerMessage)"
            }
            return "Forbidden (403). Your plan may not include API access. Upgrade your provider plan to use these endpoints."
        }

        if let providerMessage = decodeErrorBody(body) {
            return "Request failed (\(status)): \(providerMessage)"
        }
        return "Request failed with status \(status)."
    }

    static func decodeErrorBody(_ data: Data) -> String? {
        guard !data.isEmpty,
              let envelope = try? JSONDecoder().decode(ChatCompletionsErrorEnvelope.self, from: data)
        else { return nil }
        return envelope.error?.message
    }
}

// MARK: - Wire types

nonisolated struct ChatCompletionsRequestBody: Encodable, Sendable {
    nonisolated struct Message: Encodable, Sendable {
        let role: String
        let content: String
    }

    nonisolated struct Reasoning: Encodable, Sendable {
        let effort: String
    }

    nonisolated struct Provider: Encodable, Sendable {
        nonisolated struct Sort: Encodable, Sendable {
            let by: String
            let partition: String
        }

        let sort: Sort

        init(sortBy: String) {
            sort = Sort(by: sortBy, partition: "none")
        }
    }

    let model: String
    let messages: [Message]
    let stream: Bool
    let reasoning: Reasoning?
    let provider: Provider?
}

nonisolated struct ChatCompletionsStreamChunk: Decodable, Sendable {
    nonisolated struct Choice: Decodable, Sendable {
        let delta: Delta?
    }

    nonisolated struct Delta: Decodable, Sendable {
        let contentString: String?
        let contentParts: [ChatStreamContentPart]?
        let reasoning: String?
        let reasoningContent: String?

        var reasoningText: String? {
            reasoning ?? reasoningContent
        }

        var contentText: String? {
            if let contentString, !contentString.isEmpty {
                return contentString
            }
            if let contentParts {
                let joined = ChatStreamContentPart.joinedText(from: contentParts)
                return joined.isEmpty ? nil : joined
            }
            return nil
        }

        enum CodingKeys: String, CodingKey {
            case content
            case reasoning
            case reasoningContent = "reasoning_content"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            reasoning = try container.decodeIfPresent(String.self, forKey: .reasoning)
            reasoningContent = try container.decodeIfPresent(String.self, forKey: .reasoningContent)

            if let string = try? container.decode(String.self, forKey: .content) {
                contentString = string
                contentParts = nil
            } else if let parts = try? container.decode([ChatStreamContentPart].self, forKey: .content) {
                contentString = nil
                contentParts = parts
            } else {
                contentString = nil
                contentParts = nil
            }
        }
    }

    let choices: [Choice]?
    let error: ErrorPayload?
}

nonisolated struct ChatCompletionsErrorEnvelope: Decodable, Sendable {
    let error: ErrorPayload?
}

nonisolated struct ErrorPayload: Decodable, Sendable {
    let message: String
    let code: String?

    enum CodingKeys: String, CodingKey {
        case message
        case code
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.message = (try? container.decode(String.self, forKey: .message)) ?? "Unknown error"
        if let stringCode = try? container.decode(String.self, forKey: .code) {
            self.code = stringCode
        } else if let intCode = try? container.decode(Int.self, forKey: .code) {
            self.code = String(intCode)
        } else {
            self.code = nil
        }
    }
}
