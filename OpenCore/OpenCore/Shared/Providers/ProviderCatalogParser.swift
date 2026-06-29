import Foundation

/// Parses OpenAI-compatible model catalog entries into domain `ChatModel` values.
nonisolated enum ProviderCatalogParser {
    nonisolated static func chatModel(fromCatalogEntryJSON data: Data) throws -> ChatModel {
        let entry = try JSONDecoder().decode(ProviderCatalogEntry.self, from: data)
        return entry.toChatModel()
    }

    nonisolated static func chatModels(fromCatalogJSON data: Data) throws -> [ChatModel] {
        let envelope = try JSONDecoder().decode(ProviderCatalogResponse.self, from: data)
        return envelope.data
            .filter { entry in
                let modality = entry.architecture?.modality ?? ""
                return modality.isEmpty || modality.contains("text")
            }
            .map { $0.toChatModel() }
            .sorted { lhs, rhs in
                if lhs.isFree != rhs.isFree { return lhs.isFree }
                return lhs.displayName.localizedCompare(rhs.displayName) == .orderedAscending
            }
    }
}

// MARK: - Wire types

private nonisolated struct ProviderCatalogResponse: Decodable, Sendable {
    let data: [ProviderCatalogEntry]
}

private nonisolated struct ProviderCatalogEntry: Decodable, Sendable {
    let id: String
    let name: String?
    let resolvedContextLength: Int?
    let architecture: Architecture?
    let pricing: Pricing?
    let supportedParameters: [String]?
    let reasoning: Reasoning?

    enum CodingKeys: String, CodingKey {
        case id, name
        case contextLength = "context_length"
        case context
        case maxModelLen = "max_model_len"
        case architecture
        case pricing
        case supportedParameters = "supported_parameters"
        case reasoning
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        let contextLength = try container.decodeIfPresent(Int.self, forKey: .contextLength)
        let context = try container.decodeIfPresent(Int.self, forKey: .context)
        let maxModelLen = try container.decodeIfPresent(Int.self, forKey: .maxModelLen)
        resolvedContextLength = contextLength ?? context ?? maxModelLen
        architecture = try container.decodeIfPresent(Architecture.self, forKey: .architecture)
        pricing = try container.decodeIfPresent(Pricing.self, forKey: .pricing)
        supportedParameters = try container.decodeIfPresent([String].self, forKey: .supportedParameters)
        reasoning = try container.decodeIfPresent(Reasoning.self, forKey: .reasoning)
    }

    nonisolated struct Architecture: Decodable, Sendable {
        let modality: String?
        let tokenizer: String?
    }

    nonisolated struct Pricing: Decodable, Sendable {
        let prompt: String?
        let completion: String?
    }

    nonisolated struct Reasoning: Decodable, Sendable {
        let supportedEfforts: [String]?
        let mandatory: Bool?

        enum CodingKeys: String, CodingKey {
            case supportedEfforts = "supported_efforts"
            case mandatory
        }
    }

    var isFree: Bool {
        if let pricing {
            return Self.isZeroPrice(pricing.prompt) && Self.isZeroPrice(pricing.completion)
        }
        if id.hasSuffix(":free") { return true }
        return false
    }

    var supportsReasoningParameter: Bool {
        if let modality = architecture?.modality, modality.localizedCaseInsensitiveContains("reasoning") {
            return true
        }
        if supportedParameters?.contains(where: {
            $0 == "reasoning" || $0 == "reasoning_effort"
        }) == true {
            return true
        }
        if id.localizedCaseInsensitiveContains(":thinking") { return true }
        return false
    }

    var resolvedReasoningEfforts: [String] {
        if let efforts = reasoning?.supportedEfforts, !efforts.isEmpty {
            return efforts
        }
        guard supportsReasoningParameter else { return [] }
        return Self.defaultGatewayReasoningEfforts
    }

    var reasoningMandatory: Bool {
        reasoning?.mandatory == true
    }

    var supportsSpeedModes: Bool {
        if architecture?.tokenizer == "Router" { return true }
        return supportedParameters?.contains("provider") == true
    }

    var supportsImageInput: Bool {
        guard let modality = architecture?.modality, !modality.isEmpty else { return false }
        return modality.localizedCaseInsensitiveContains("image")
    }

    var supportsVideoInput: Bool {
        guard let modality = architecture?.modality, !modality.isEmpty else { return false }
        return modality.localizedCaseInsensitiveContains("video")
    }

    func toChatModel() -> ChatModel {
        ChatModel(
            id: id,
            displayName: name ?? id,
            isFree: isFree,
            contextLength: resolvedContextLength,
            supportedReasoningEfforts: resolvedReasoningEfforts,
            reasoningMandatory: reasoningMandatory,
            supportsSpeedModes: supportsSpeedModes,
            supportsImageInput: supportsImageInput,
            supportsVideoInput: supportsVideoInput
        )
    }

    private static let defaultGatewayReasoningEfforts = [
        "max", "xhigh", "high", "medium", "low", "minimal", "none"
    ]

    private static func isZeroPrice(_ value: String?) -> Bool {
        guard let value else { return false }
        guard let decimal = Decimal(string: value) else { return value == "0" }
        return decimal == 0
    }
}
