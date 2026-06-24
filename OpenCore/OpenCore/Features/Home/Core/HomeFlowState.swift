import Foundation

nonisolated struct HomeFlowState: Equatable, Sendable {
    var selectedProviderID: String = SidePanelProviderAPI.default.id
    var selectedModelID: String?
    var reasoningModel: SidePanelReasoningModel = .high
    var speedMode: HomeComposerSpeedMode = .standard
    var contextUsage = ContextWindowUsage.zero
    var hasAPIKey = false
    var catalogModels: [ChatModel] = []
    var catalogError: String?
    var isModelPopupPresented = false
    var modelSearchQuery = ""
    var appliedSearchQuery = ""
    var modelFilterFreeOnly = false

    var availableModels: [HomeModelOption] {
        catalogModels.map { HomeModelOption(model: $0) }
    }

    /// True when the provider catalog has been loaded and offers at least one model.
    var isModelCatalogAvailable: Bool { !catalogModels.isEmpty }

    /// True when the loaded catalog includes at least one free-tier model.
    var hasFreeTierModels: Bool { catalogModels.contains(where: \.isFree) }

    var modelPickerTitle: String {
        guard isModelCatalogAvailable else { return "Not Available" }
        return selectedModelOption?.title ?? "Select model"
    }

    var selectedModelOption: HomeModelOption? {
        guard let selectedModelID,
              let model = catalogModels.first(where: { $0.id == selectedModelID }) else {
            return nil
        }
        return HomeModelOption(model: model)
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

    var hasSelectedModel: Bool { isModelCatalogAvailable && selectedModelOption != nil }

    /// OpenRouter throughput routing when the selected model supports speed modes.
    var activeProviderSortBy: String? {
        guard let modes = selectedModelOption?.availableSpeedModes, !modes.isEmpty else { return nil }
        return speedMode.providerSortBy
    }
}
