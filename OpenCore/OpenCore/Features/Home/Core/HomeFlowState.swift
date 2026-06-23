import Foundation

nonisolated struct HomeFlowState: Equatable, Sendable {
    var selectedProviderID: String = SidePanelProviderAPI.default.id
    var selectedModelID: String?
    var reasoningModel: SidePanelReasoningModel = .high
    var speedMode: HomeComposerSpeedMode = .standard
    var contextUsage = HomeComposerContextUsage(usedTokens: 107_000, tokenLimit: 258_000)
    var hasAPIKey = false
    var catalogModels: [ChatModel] = []
    var catalogError: String?
    var isModelPopupPresented = false
    var modelSearchQuery = ""
    var appliedSearchQuery = ""
    var modelFilterFreeOnly = false
    var shouldAutoSelectDefaultModel = true

    var availableModels: [HomeModelOption] {
        let source = catalogModels.isEmpty
            ? ChatModel.curatedFallback(for: selectedProviderID)
            : catalogModels
        return source.map { HomeModelOption(model: $0) }
    }

    var selectedModelOption: HomeModelOption? {
        guard let selectedModelID else { return nil }
        if let match = availableModels.first(where: { $0.id == selectedModelID }) {
            return match
        }
        return HomeModelOption(id: selectedModelID, title: HomeModelCatalog.displayTitle(for: selectedModelID))
    }

    var filteredModels: [HomeModelOption] {
        var result = availableModels
        if modelFilterFreeOnly {
            result = result.filter(\.isFree)
        }
        let query = appliedSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return result }
        return result.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.id.localizedCaseInsensitiveContains(query)
        }
    }

    var hasSelectedModel: Bool { selectedModelOption != nil }
}
