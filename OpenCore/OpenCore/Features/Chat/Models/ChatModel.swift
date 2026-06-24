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
