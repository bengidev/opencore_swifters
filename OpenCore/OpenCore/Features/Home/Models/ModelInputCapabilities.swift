import Foundation

nonisolated struct ModelInputCapabilities: Equatable, Sendable {
    let inputModalities: Set<ModelInputModality>

    var supportsFileInput: Bool { inputModalities.contains(.file) }
    var supportsImageInput: Bool { inputModalities.contains(.image) }
    var supportsVideoInput: Bool { inputModalities.contains(.video) }
    var supportsAudioInput: Bool { inputModalities.contains(.audio) }
    var supportsAttachments: Bool {
        inputModalities.contains { $0 != .text }
    }

    static func from(_ model: ChatModel) -> ModelInputCapabilities {
        var modalities: Set<ModelInputModality> = [.text]
        if model.supportsFileInput { modalities.insert(.file) }
        if model.supportsImageInput { modalities.insert(.image) }
        if model.supportsVideoInput { modalities.insert(.video) }
        if model.supportsAudioInput { modalities.insert(.audio) }
        return ModelInputCapabilities(inputModalities: modalities)
    }

    var accessibilitySummary: String {
        var parts: [String] = []
        if supportsFileInput { parts.append("file") }
        if supportsImageInput { parts.append("image") }
        if supportsVideoInput { parts.append("video") }
        if supportsAudioInput { parts.append("audio") }
        guard !parts.isEmpty else { return "" }
        return "supports \(parts.joined(separator: " and ")) input"
    }
}
