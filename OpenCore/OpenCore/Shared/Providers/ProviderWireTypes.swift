import Foundation

// MARK: - Request body

nonisolated struct ProviderChatContentPart: Encodable, Sendable, Equatable {
    nonisolated struct ImageURLPayload: Encodable, Sendable, Equatable {
        let url: String
    }

    nonisolated struct VideoURLPayload: Encodable, Sendable, Equatable {
        let url: String
    }

    let type: String
    let text: String?
    let imageURL: ImageURLPayload?
    let videoURL: VideoURLPayload?

    static func text(_ value: String) -> Self {
        Self(type: "text", text: value, imageURL: nil, videoURL: nil)
    }

    static func imageURL(_ dataURL: String) -> Self {
        Self(
            type: "image_url",
            text: nil,
            imageURL: ImageURLPayload(url: dataURL),
            videoURL: nil
        )
    }

    static func videoURL(_ dataURL: String) -> Self {
        Self(
            type: "video_url",
            text: nil,
            imageURL: nil,
            videoURL: VideoURLPayload(url: dataURL)
        )
    }

    enum CodingKeys: String, CodingKey {
        case type, text
        case imageURL = "image_url"
        case videoURL = "video_url"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        switch type {
        case "text":
            try container.encode(text, forKey: .text)
        case "image_url":
            try container.encode(imageURL, forKey: .imageURL)
        case "video_url":
            try container.encode(videoURL, forKey: .videoURL)
        default:
            break
        }
    }
}

nonisolated enum ProviderChatMessageContent: Encodable, Sendable, Equatable {
    case text(String)
    case parts([ProviderChatContentPart])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .text(string):
            try container.encode(string)
        case let .parts(parts):
            try container.encode(parts)
        }
    }
}

nonisolated struct ProviderChatCompletionsRequestBody: Encodable, Sendable {
    nonisolated struct Message: Encodable, Sendable {
        let role: String
        let content: ProviderChatMessageContent
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
