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
    private var contextMessages: [ChatMessage] = []
    private var contextDraft = ""

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
        state.reasoningModel = preference.reasoningModel
        await loadCatalog(allowAutoSelect: preference.modelID == nil)
    }

    func refreshAPIKeyStatus() {
        state.hasAPIKey = credentialStore.secret(for: state.selectedProviderID) != nil
    }

    func handleCredentialsChanged() async {
        refreshAPIKeyStatus()
        state.catalogModels = []
        state.catalogError = nil
        await loadCatalog(allowAutoSelect: state.selectedModelID == nil)
    }

    func handleProviderChanged(_ providerID: String) async {
        state.selectedProviderID = providerID
        providerPreference.setProviderID(providerID)
        providerPreference.setModelID(nil)
        state.selectedModelID = nil
        state.catalogModels = []
        state.catalogError = nil
        refreshAPIKeyStatus()
        await loadCatalog(allowAutoSelect: true)
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
        refreshStoredContextUsage()
        onModelSelectionChanged?()
    }

    func selectReasoningModel(_ level: SidePanelReasoningModel) {
        providerPreference.setReasoningModel(level)
        state.reasoningModel = level
    }

    func selectSpeedMode(_ speedMode: HomeComposerSpeedMode) {
        guard let option = state.selectedModelOption,
              option.availableSpeedModes.contains(speedMode) else { return }
        state.speedMode = speedMode
    }

    func updateContextInputs(messages: [ChatMessage], draftMessage: String) {
        contextMessages = messages
        contextDraft = draftMessage
        refreshStoredContextUsage()
    }

    func refreshContextUsage(messages: [ChatMessage], draftMessage: String) {
        state.contextUsage = ContextWindowEstimator.estimate(
            messages: messages,
            draft: draftMessage,
            contextLength: state.selectedModelOption?.contextLength
        )
    }

    func setModelPopupPresented(_ isPresented: Bool) {
        state.isModelPopupPresented = isPresented
        if isPresented {
            state.modelSearchQuery = ""
            state.appliedSearchQuery = ""
            state.modelFilterFreeOnly = false
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

    private func loadCatalog(allowAutoSelect: Bool) async {
        let provider = SidePanelProviderAPI.resolve(id: state.selectedProviderID)
        let secret = credentialStore.secret(for: state.selectedProviderID)
        let result = await catalog.listModels(provider, secret, cachePreference, .shared)
        state.catalogModels = result.models
        state.catalogError = result.errorHint
        reconcileModelSelection(allowAutoSelect: allowAutoSelect)
        refreshStoredContextUsage()
        onModelSelectionChanged?()
    }

    private func reconcileModelSelection(allowAutoSelect: Bool) {
        let models = state.catalogModels
        guard !models.isEmpty else {
            clearSelectedModelIfNeeded()
            return
        }

        if let selectedModelID = state.selectedModelID,
           models.contains(where: { $0.id == selectedModelID }) {
            return
        }

        let shouldAutoSelect = allowAutoSelect || state.selectedModelID != nil
        guard shouldAutoSelect else { return }

        applyDefaultModel(models[0])
    }

    private func applyDefaultModel(_ model: ChatModel) {
        providerPreference.setProviderID(state.selectedProviderID)
        providerPreference.setModelID(model.id)
        state.selectedModelID = model.id

        if let option = state.selectedModelOption,
           !option.availableSpeedModes.contains(state.speedMode) {
            state.speedMode = .standard
        }
    }

    private func clearSelectedModelIfNeeded() {
        guard state.selectedModelID != nil else { return }
        state.selectedModelID = nil
        providerPreference.setModelID(nil)
    }

    private func refreshStoredContextUsage() {
        refreshContextUsage(messages: contextMessages, draftMessage: contextDraft)
    }
}
