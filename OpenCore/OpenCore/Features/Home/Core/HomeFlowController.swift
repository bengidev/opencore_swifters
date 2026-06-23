import Foundation
import Observation

@MainActor
@Observable
final class HomeFlowController {
    private(set) var state: HomeFlowState
    private let catalog: HomeModelCatalogClient
    private let cachePreference: HomeModelCatalogCachePreferenceClient
    private let credentialStore: any SidePanelCredentialStore
    private let providerPreference: any SidePanelProviderPreferenceStore
    private var searchDebounceTask: Task<Void, Never>?

    var onModelSelectionChanged: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    init(
        state: HomeFlowState = HomeFlowState(),
        catalog: HomeModelCatalogClient = .live,
        cachePreference: HomeModelCatalogCachePreferenceClient = .live,
        credentialStore: any SidePanelCredentialStore,
        providerPreference: any SidePanelProviderPreferenceStore
    ) {
        self.state = state
        self.catalog = catalog
        self.cachePreference = cachePreference
        self.credentialStore = credentialStore
        self.providerPreference = providerPreference
    }

    func onAppear() async {
        refreshAPIKeyStatus()
        let preference = providerPreference.preference()
        state.selectedProviderID = preference.providerID ?? SidePanelProviderAPI.default.id
        state.selectedModelID = preference.modelID
        state.shouldAutoSelectDefaultModel = preference.modelID == nil
        state.reasoningModel = preference.reasoningModel
        await loadCatalog()
    }

    func refreshAPIKeyStatus() {
        state.hasAPIKey = credentialStore.secret(for: state.selectedProviderID) != nil
    }

    func handleCredentialsChanged() {
        refreshAPIKeyStatus()
    }

    func handleProviderChanged(_ providerID: String) async {
        state.selectedProviderID = providerID
        providerPreference.setProviderID(providerID)
        providerPreference.setModelID(nil)
        state.selectedModelID = nil
        state.catalogModels = []
        state.catalogError = nil
        state.shouldAutoSelectDefaultModel = true
        refreshAPIKeyStatus()
        await loadCatalog()
        onModelSelectionChanged?()
    }

    func handleReasoningModelChanged() {
        state.reasoningModel = providerPreference.preference().reasoningModel
    }

    func selectModel(_ modelID: String) {
        providerPreference.setProviderID(state.selectedProviderID)
        providerPreference.setModelID(modelID)
        state.selectedModelID = modelID
        state.isModelPopupPresented = false
        if let option = state.selectedModelOption,
           !option.availableSpeedModes.contains(state.speedMode) {
            state.speedMode = .standard
        }
        onModelSelectionChanged?()
    }

    func selectReasoningModel(_ level: SidePanelReasoningModel) {
        providerPreference.setReasoningModel(level)
        state.reasoningModel = level
    }

    func selectSpeedMode(_ speedMode: HomeComposerSpeedMode) {
        state.speedMode = speedMode
    }

    func setModelPopupPresented(_ isPresented: Bool) {
        state.isModelPopupPresented = isPresented
        if isPresented {
            state.modelSearchQuery = ""
            state.appliedSearchQuery = ""
            state.modelFilterFreeOnly = state.selectedProviderID == SidePanelProviderAPI.openRouter.id
        }
    }

    func setModelSearchQuery(_ query: String) {
        state.modelSearchQuery = query
        searchDebounceTask?.cancel()
        searchDebounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let self else { return }
            state.appliedSearchQuery = query
        }
    }

    func setModelFilterFreeOnly(_ freeOnly: Bool) {
        state.modelFilterFreeOnly = freeOnly
    }

    private func loadCatalog() async {
        let provider = SidePanelProviderAPI.resolve(id: state.selectedProviderID)
        let secret = credentialStore.secret(for: state.selectedProviderID)
        let result = await catalog.listModels(provider, secret, cachePreference, .shared)
        state.catalogModels = result.models
        state.catalogError = result.errorHint
        reconcileModelSelection(allowAutoSelect: state.shouldAutoSelectDefaultModel)
        state.shouldAutoSelectDefaultModel = false
        onModelSelectionChanged?()
    }

    private func reconcileModelSelection(allowAutoSelect: Bool) {
        let models = state.availableModels
        guard !models.isEmpty else { return }

        if let selectedModelID = state.selectedModelID,
           models.contains(where: { $0.id == selectedModelID }) {
            return
        } else if !allowAutoSelect {
            return
        }

        let defaultModel = models[0]
        providerPreference.setProviderID(state.selectedProviderID)
        providerPreference.setModelID(defaultModel.id)
        state.selectedModelID = defaultModel.id

        if let option = state.selectedModelOption,
           !option.availableSpeedModes.contains(state.speedMode) {
            state.speedMode = .standard
        }
    }
}
