import Foundation

// MARK: - Request body

nonisolated struct ProviderChatCompletionsRequestBody: Encodable, Sendable {
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
    let reasoningEffort: String?
    let provider: Provider?

    enum CodingKeys: String, CodingKey {
        case model, messages, stream, reasoning, provider
        case reasoningEffort = "reasoning_effort"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(messages, forKey: .messages)
        try container.encode(stream, forKey: .stream)
        try container.encodeIfPresent(reasoning, forKey: .reasoning)
        try container.encodeIfPresent(reasoningEffort, forKey: .reasoningEffort)
        try container.encodeIfPresent(provider, forKey: .provider)
    }
}

// MARK: - Stream chunk

nonisolated struct ProviderChatCompletionsStreamChunk: Decodable, Sendable {
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
    let error: ProviderErrorPayload?
}

nonisolated struct ProviderChatCompletionsErrorEnvelope: Decodable, Sendable {
    let error: ProviderErrorPayload?
}

nonisolated struct ProviderErrorPayload: Decodable, Sendable {
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
