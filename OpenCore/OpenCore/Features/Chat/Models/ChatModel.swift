import Foundation

/// A model entry from the provider catalog.
nonisolated struct ChatModel: Equatable, Identifiable, Sendable, Codable {
    let id: String
    let displayName: String
    let isFree: Bool
    let contextLength: Int?
    /// Reasoning effort wire values from the provider catalog (`supported_efforts`).
    let supportedReasoningEfforts: [String]
    /// When true, the model rejects disabling reasoning (no Off option).
    let reasoningMandatory: Bool
    /// OpenRouter router models expose provider speed routing (standard vs fast).
    let supportsSpeedModes: Bool

    var supportsReasoning: Bool { !supportedReasoningEfforts.isEmpty }

    init(
        id: String,
        displayName: String,
        isFree: Bool = false,
        contextLength: Int? = nil,
        supportedReasoningEfforts: [String] = [],
        reasoningMandatory: Bool = false,
        supportsSpeedModes: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.isFree = isFree
        self.contextLength = contextLength
        self.supportedReasoningEfforts = supportedReasoningEfforts
        self.reasoningMandatory = reasoningMandatory
        self.supportsSpeedModes = supportsSpeedModes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        isFree = try container.decodeIfPresent(Bool.self, forKey: .isFree) ?? false
        contextLength = try container.decodeIfPresent(Int.self, forKey: .contextLength)
        if let efforts = try container.decodeIfPresent([String].self, forKey: .supportedReasoningEfforts) {
            supportedReasoningEfforts = efforts
        } else if try container.decodeIfPresent(Bool.self, forKey: .supportsReasoning) == true {
            supportedReasoningEfforts = ["low", "medium", "high"]
        } else {
            supportedReasoningEfforts = []
        }
        reasoningMandatory = try container.decodeIfPresent(Bool.self, forKey: .reasoningMandatory) ?? false
        supportsSpeedModes = try container.decodeIfPresent(Bool.self, forKey: .supportsSpeedModes) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(isFree, forKey: .isFree)
        try container.encodeIfPresent(contextLength, forKey: .contextLength)
        try container.encode(supportedReasoningEfforts, forKey: .supportedReasoningEfforts)
        try container.encode(reasoningMandatory, forKey: .reasoningMandatory)
        try container.encode(supportsSpeedModes, forKey: .supportsSpeedModes)
    }

    private enum CodingKeys: String, CodingKey {
        case id, displayName, isFree, contextLength
        case supportedReasoningEfforts
        case reasoningMandatory
        case supportsSpeedModes
        case supportsReasoning
    }
}
