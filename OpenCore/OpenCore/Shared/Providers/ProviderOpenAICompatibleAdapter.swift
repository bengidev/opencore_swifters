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

        let payload = try Self.makeRequestBody(
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

    func makeModelDetailURLRequest(modelID: String, secret: String) -> URLRequest? { nil }

    static func makeRequestBody(
        chatRequest: ChatRequest,
        reasoningWireStyle: ProviderReasoningWireStyle,
        supportsProviderRouting: Bool
    ) throws -> ProviderChatCompletionsRequestBody {
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
            messages: try wireMessages(from: chatRequest.messages),
            stream: true,
            reasoning: reasoningObject,
            reasoningEffort: reasoningEffort,
            provider: providerSort.map {
                ProviderChatCompletionsRequestBody.Provider(sortBy: $0)
            }
        )
    }

    static func wireMessages(from messages: [ChatMessage]) throws -> [ProviderChatCompletionsRequestBody.Message] {
        try messages.compactMap { message in
            switch message {
            case let .text(text):
                return ProviderChatCompletionsRequestBody.Message(
                    role: text.role.rawValue,
                    content: try wireMessageContent(for: text)
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

    static func wireMessageContent(for text: ChatTextMessage) throws -> ProviderChatMessageContent {
        if let parts = try historicalContentParts(
            modelText: text.providerContent,
            attachments: text.attachments
        ) {
            return .parts(parts)
        }
        return .text(text.providerContent)
    }

    private static func historicalContentParts(
        modelText: String,
        attachments: [ChatMessageAttachment]
    ) throws -> [ProviderChatContentPart]? {
        guard ChatMultimodalWireLogic.hasVisualMedia(attachments) else { return nil }

        var parts: [ProviderChatContentPart] = []
        let trimmedText = modelText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedText.isEmpty {
            parts.append(.text(trimmedText))
        }

        for attachment in attachments where attachment.kind == .image {
            do {
                let single = try ChatMultimodalWireLogic.makeContentParts(
                    modelText: "",
                    attachments: [attachment]
                )
                if let imagePart = single?.first(where: { $0.type == "image_url" }) {
                    parts.append(imagePart)
                }
            } catch ChatAttachmentError.visualEncodingFailed {
                guard attachment.wireImageDataURL == nil,
                      !FileManager.default.fileExists(atPath: attachment.localPath) else {
                    throw ChatAttachmentError.visualEncodingFailed(filename: attachment.filename)
                }
            }
        }

        for attachment in attachments where attachment.kind == .video {
            do {
                let single = try ChatMultimodalWireLogic.makeContentParts(
                    modelText: "",
                    attachments: [attachment]
                )
                if let videoPart = single?.first(where: { $0.type == "video_url" }) {
                    parts.append(videoPart)
                }
            } catch ChatAttachmentError.visualEncodingFailed {
                guard attachment.wireVideoDataURL == nil,
                      !FileManager.default.fileExists(atPath: attachment.localPath) else {
                    throw ChatAttachmentError.visualEncodingFailed(filename: attachment.filename)
                }
            }
        }

        let hasVisualPart = parts.contains { part in
            part.type == "image_url" || part.type == "video_url"
        }
        return hasVisualPart ? parts : nil
    }


    static func mapStreamPayload(_ payload: String) -> [ChatStreamingEvent]? {
        mapStreamPayload(payload, streamedChoiceIndices: []).events
    }

    static func mapStreamPayload(
        _ payload: String,
        streamedChoiceIndices: Set<Int>
    ) -> (events: [ChatStreamingEvent], streamedChoiceIndices: Set<Int>) {
        guard let data = payload.data(using: .utf8) else {
            return ([], streamedChoiceIndices)
        }

        if let sideband = ProviderStreamOutputEventMapper.mapSidebandPayload(data) {
            return (sideband, streamedChoiceIndices)
        }

        let chunk = try? JSONDecoder().decode(ProviderChatCompletionsStreamChunk.self, from: data)
        guard let chunk else { return ([], streamedChoiceIndices) }

        if let error = chunk.error {
            return ([.error(ChatStreamError(message: error.message))], streamedChoiceIndices)
        }

        var events: [ChatStreamingEvent] = []
        var streamed = streamedChoiceIndices
        for (choiceIndex, choice) in (chunk.choices ?? []).enumerated() {
            if let delta = choice.delta, delta.hasStreamableContent {
                let mapped = mapAssistantPayload(delta)
                events.append(contentsOf: mapped)
                if mapped.contains(where: { event in
                    if case .textDelta = event { return true }
                    return false
                }) {
                    streamed.insert(choiceIndex)
                }
            }
            if let message = choice.message,
               choice.delta?.hasStreamableContent != true,
               !streamed.contains(choiceIndex) {
                let mapped = mapAssistantPayload(message)
                events.append(contentsOf: mapped)
                if mapped.contains(where: { event in
                    if case .textDelta = event { return true }
                    return false
                }) {
                    streamed.insert(choiceIndex)
                }
            }
        }
        return (events.isEmpty ? [] : events, streamed)
    }

    static func mapAssistantPayload(_ payload: ProviderChatCompletionsStreamChunk.Delta) -> [ChatStreamingEvent] {
        var events: [ChatStreamingEvent] = []
        if let reasoning = payload.reasoningText,
           !reasoning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            events.append(.thinkingDelta(reasoning))
        }
        if let contentParts = payload.contentParts {
            events.append(contentsOf: ProviderStreamOutputEventMapper.mapContentParts(contentParts))
        }
        if let content = payload.contentText, !content.isEmpty {
            events.append(.textDelta(content))
        }
        return events
    }

    static func decodeErrorBody(_ data: Data) -> String? {
        guard !data.isEmpty,
              let envelope = try? JSONDecoder().decode(ProviderChatCompletionsErrorEnvelope.self, from: data)
        else { return nil }
        return envelope.error?.message
    }
}
