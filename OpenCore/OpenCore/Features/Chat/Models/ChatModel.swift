import Foundation

/// A model entry from the provider catalog.
nonisolated struct ChatModel: Equatable, Identifiable, Sendable, Codable {
    let id: String
    let displayName: String
    let isFree: Bool
    let contextLength: Int?
    let supportsReasoning: Bool
    /// OpenRouter router models expose provider speed routing (standard vs fast).
    let supportsSpeedModes: Bool

    init(
        id: String,
        displayName: String,
        isFree: Bool = false,
        contextLength: Int? = nil,
        supportsReasoning: Bool = false,
        supportsSpeedModes: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.isFree = isFree
        self.contextLength = contextLength
        self.supportsReasoning = supportsReasoning
        self.supportsSpeedModes = supportsSpeedModes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        isFree = try container.decodeIfPresent(Bool.self, forKey: .isFree) ?? false
        contextLength = try container.decodeIfPresent(Int.self, forKey: .contextLength)
        supportsReasoning = try container.decodeIfPresent(Bool.self, forKey: .supportsReasoning) ?? false
        supportsSpeedModes = try container.decodeIfPresent(Bool.self, forKey: .supportsSpeedModes) ?? false
    }
}

extension ChatModel {
    nonisolated static let curatedFallback: [ChatModel] = [
        ChatModel(
            id: "meta-llama/llama-3.3-70b-instruct:free",
            displayName: "Llama 3.3 70B",
            isFree: true,
            contextLength: 131_072,
            supportsReasoning: false
        ),
        ChatModel(
            id: "deepseek/deepseek-r1:free",
            displayName: "DeepSeek R1",
            isFree: true,
            contextLength: 163_840,
            supportsReasoning: true
        ),
        ChatModel(
            id: "google/gemini-2.0-flash-exp:free",
            displayName: "Gemini 2.0 Flash",
            isFree: true,
            contextLength: 1_048_576,
            supportsReasoning: false
        ),
        ChatModel(
            id: "mistralai/mistral-7b-instruct:free",
            displayName: "Mistral 7B",
            isFree: true,
            contextLength: 32_768,
            supportsReasoning: false
        ),
        ChatModel(
            id: "qwen/qwen3-14b:free",
            displayName: "Qwen3 14B",
            isFree: true,
            contextLength: 40_960,
            supportsReasoning: true
        )
    ]

    nonisolated static let commandCodeFallback: [ChatModel] = [
        ChatModel(id: "moonshotai/Kimi-K2.5", displayName: "Kimi K2.5", isFree: true, contextLength: 131_072, supportsReasoning: true),
        ChatModel(id: "deepseek/deepseek-v4-flash", displayName: "DeepSeek V4 Flash", isFree: true, contextLength: 131_072),
        ChatModel(id: "deepseek/deepseek-v4-pro", displayName: "DeepSeek V4 Pro", contextLength: 131_072, supportsReasoning: true),
        ChatModel(id: "Qwen/Qwen3.7-Max", displayName: "Qwen 3.7 Max", contextLength: 131_072, supportsReasoning: true),
        ChatModel(id: "claude-sonnet-4-6", displayName: "Claude Sonnet 4.6", contextLength: 200_000, supportsReasoning: true)
    ]

    nonisolated static let openCodeFallback: [ChatModel] = [
        ChatModel(id: "meta-llama/llama-3.3-70b-instruct:free", displayName: "Llama 3.3 70B", isFree: true, contextLength: 131_072),
        ChatModel(id: "deepseek/deepseek-r1:free", displayName: "DeepSeek R1", isFree: true, contextLength: 163_840, supportsReasoning: true),
        ChatModel(id: "qwen/qwen3-14b:free", displayName: "Qwen3 14B", isFree: true, contextLength: 40_960, supportsReasoning: true)
    ]

    nonisolated static func curatedFallback(for providerID: String?) -> [ChatModel] {
        switch providerID {
        case "commandcode": return commandCodeFallback
        case "opencode": return openCodeFallback
        default: return curatedFallback
        }
    }
}
