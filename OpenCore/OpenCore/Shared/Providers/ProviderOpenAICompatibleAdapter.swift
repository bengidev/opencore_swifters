import Foundation

/// Default adapter for OpenAI-compatible chat providers. Parameterized by
/// descriptor and reasoning wire style so new backends are values, not classes.
nonisolated struct ProviderOpenAICompatibleAdapter: ProviderAdapting {
    let descriptor: ProviderDescriptor
    let reasoningWireStyle: ProviderReasoningWireStyle
    let supportsProviderRouting: Bool

    init(
        descriptor: ProviderDescriptor,
        reasoningWireStyle: ProviderReasoningWireStyle = .topLevelEffort,
        supportsProviderRouting: Bool = false
    ) {
        self.descriptor = descriptor
        self.reasoningWireStyle = reasoningWireStyle
        self.supportsProviderRouting = supportsProviderRouting
    }

    func makeChatCompletionURLRequest(secret: String, chatRequest: ChatRequest) throws -> URLRequest {
        var urlRequest = URLRequest(url: descriptor.chatCompletionsURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        for (field, value) in descriptor.defaultHeaders {
            urlRequest.setValue(value, forHTTPHeaderField: field)
        }

        switch descriptor.authScheme {
        case .bearer:
            urlRequest.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }

        let payload = Self.makeRequestBody(
            chatRequest: chatRequest,
            reasoningWireStyle: reasoningWireStyle,
            supportsProviderRouting: supportsProviderRouting
        )
        urlRequest.httpBody = try JSONEncoder().encode(payload)
        return urlRequest
    }

    func makeModelsListURLRequest(secret: String) -> URLRequest {
        var request = URLRequest(url: descriptor.modelsURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (field, value) in descriptor.defaultHeaders {
            request.setValue(value, forHTTPHeaderField: field)
        }
        switch descriptor.authScheme {
        case .bearer:
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    static func makeRequestBody(
        chatRequest: ChatRequest,
        reasoningWireStyle: ProviderReasoningWireStyle,
        supportsProviderRouting: Bool
    ) -> ProviderChatCompletionsRequestBody {
        let effort = chatRequest.reasoningEffort
        let reasoningObject: ProviderChatCompletionsRequestBody.Reasoning?
        let reasoningEffort: String?

        switch reasoningWireStyle {
        case .reasoningObject:
            reasoningObject = effort.map { ProviderChatCompletionsRequestBody.Reasoning(effort: $0) }
            reasoningEffort = nil
        case .topLevelEffort:
            reasoningObject = nil
            reasoningEffort = effort
        }

        let providerSort = supportsProviderRouting
            ? chatRequest.providerSortBy
            : nil

        return ProviderChatCompletionsRequestBody(
            model: chatRequest.modelID,
            messages: wireMessages(from: chatRequest.messages),
            stream: true,
            reasoning: reasoningObject,
            reasoningEffort: reasoningEffort,
            provider: providerSort.map {
                ProviderChatCompletionsRequestBody.Provider(sortBy: $0)
            }
        )
    }

    static func wireMessages(from messages: [ChatMessage]) -> [ProviderChatCompletionsRequestBody.Message] {
        messages.compactMap { message in
            switch message {
            case let .text(text):
                return ProviderChatCompletionsRequestBody.Message(
                    role: text.role.rawValue,
                    content: wireMessageContent(for: text)
                )
            case let .system(system):
                return ProviderChatCompletionsRequestBody.Message(
                    role: system.role.rawValue,
                    content: .text(system.content)
                )
            case .thinking:
                return nil
            case .outputStream:
                return nil
            }
        }
    }

    static func wireMessageContent(for text: ChatTextMessage) -> ProviderChatMessageContent {
        if let parts = ChatMultimodalWireLogic.makeContentParts(
            visibleText: text.content,
            attachments: text.attachments
        ) {
            return .parts(parts)
        }
        return .text(text.providerContent)
    }

    static func mapStreamPayload(_ payload: String) -> [ChatStreamingEvent]? {
        guard let data = payload.data(using: .utf8) else { return nil }

        if let sideband = ProviderStreamOutputEventMapper.mapSidebandPayload(data) {
            return sideband
        }

        let chunk = try? JSONDecoder().decode(ProviderChatCompletionsStreamChunk.self, from: data)
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
            if let contentParts = choice.delta?.contentParts {
                events.append(contentsOf: ProviderStreamOutputEventMapper.mapContentParts(contentParts))
            }
            if let content = choice.delta?.contentText, !content.isEmpty {
                events.append(.textDelta(content))
            }
        }
        return events.isEmpty ? nil : events
    }

    static func decodeErrorBody(_ data: Data) -> String? {
        guard !data.isEmpty,
              let envelope = try? JSONDecoder().decode(ProviderChatCompletionsErrorEnvelope.self, from: data)
        else { return nil }
        return envelope.error?.message
    }
}
