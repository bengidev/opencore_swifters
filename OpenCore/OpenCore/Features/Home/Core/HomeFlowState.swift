import Foundation

nonisolated struct HomeFlowState: Equatable, Sendable {
    var selectedTab: HomeTab = .home
    var selectedProviderID: String = ProviderDescriptor.openRouter.id
    var selectedModelID: String?
    var reasoningEffortWireValue: String? = "high"
    var speedMode: HomeComposerSpeedMode = .standard
    var contextUsage = ContextWindowUsage.zero
    var hasAPIKey = false
    var catalogModels: [ChatModel] = []
    var catalogError: String?
    var isModelPopupPresented = false
    var modelSearchQuery = ""
    var appliedSearchQuery = ""
    var modelFilterFreeOnly = false

    /// OpenRouter throughput routing when the selected model supports speed modes.
    var activeProviderSortBy: String? {
        guard let modes = selectedModelOption?.availableSpeedModes, !modes.isEmpty else { return nil }
        return speedMode.providerSortBy
    }

    /// Reasoning effort sent on the next request, or `nil` when unsupported/off.
    var activeReasoningEffort: String? {
        guard let option = selectedModelOption, !option.availableReasoningEfforts.isEmpty else {
            return nil
        }
        return option.resolvedReasoningEffort(
            storedWireValue: reasoningEffortWireValue
        ).requestEffort
    }

    func modelOption(for model: ChatModel) -> HomeModelOption {
        let adapter = ProviderRegistry.resolve(id: selectedProviderID)
        return HomeModelOption(model: model, providerSupportsRouting: adapter.supportsProviderRouting)
    }

    var availableModels: [HomeModelOption] {
        catalogModels.map { modelOption(for: $0) }
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
        return modelOption(for: model)
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
}
