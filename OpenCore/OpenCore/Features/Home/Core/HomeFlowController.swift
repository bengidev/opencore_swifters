import Foundation
import Observation

@MainActor
@Observable
final class HomeFlowController {
    private(set) var state: HomeFlowState
    private let catalog: HomeModelCatalogClient
    private let cachePreference: HomeModelCatalogCachePreferenceClient
    private let capabilityClient: HomeModelCapabilityClient
    private let credentialStore: any CredentialStoring
    private let providerPreference: any SidePanelProviderPreferenceStore
    private var searchDebounceTask: Task<Void, Never>?
    private var capabilityFetchTask: Task<Void, Never>?
    private var contextMessages: [ChatMessage] = []
    private var contextDraft = ""

    var onModelSelectionChanged: (() -> Void)?
    var onInputCapabilitiesResolved: ((ModelInputCapabilities) -> Void)?

    func selectTab(_ tab: HomeTab) {
        state.selectedTab = tab
    }

    func openSettingsTab() {
        state.selectedTab = .settings
    }

    init(
        state: HomeFlowState = HomeFlowState(),
        catalog: HomeModelCatalogClient = .live,
        cachePreference: HomeModelCatalogCachePreferenceClient = .live,
        capabilityClient: HomeModelCapabilityClient = .live,
        credentialStore: any CredentialStoring,
        providerPreference: any SidePanelProviderPreferenceStore
    ) {
        self.state = state
        self.catalog = catalog
        self.cachePreference = cachePreference
        self.capabilityClient = capabilityClient
        self.credentialStore = credentialStore
        self.providerPreference = providerPreference
    }

    func onAppear() async {
        refreshAPIKeyStatus()
        let preference = providerPreference.preference()
        state.selectedProviderID = preference.providerID ?? ProviderDescriptor.openRouter.id
        state.selectedModelID = preference.modelID
        state.reasoningEffortWireValue = preference.reasoningEffortWireValue
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
        state.inputCapabilities = nil
        refreshAPIKeyStatus()
        await loadCatalog(allowAutoSelect: true)
    }

    func handleReasoningModelChanged() {
        state.reasoningEffortWireValue = providerPreference.preference().reasoningEffortWireValue
    }

    func selectModel(_ modelID: String) {
        providerPreference.setProviderID(state.selectedProviderID)
        providerPreference.setModelID(modelID)
        state.selectedModelID = modelID
        state.isModelPopupPresented = false
        if let option = state.selectedModelOption {
            if !option.availableSpeedModes.contains(state.speedMode) {
                state.speedMode = .standard
            }
            reconcileReasoningSelection(for: option)
        }
        refreshStoredContextUsage()
        onModelSelectionChanged?()
        refreshInputCapabilities()
    }

    func selectReasoningEffort(_ effort: ModelReasoningEffort) {
        guard let option = state.selectedModelOption,
              option.availableReasoningEfforts.contains(effort) else { return }
        providerPreference.setReasoningEffort(effort)
        state.reasoningEffortWireValue = effort.wireValue
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
            state.isContextUsagePresented = false
        }
    }

    func setContextUsagePresented(_ isPresented: Bool) {
        state.isContextUsagePresented = isPresented
        if isPresented {
            state.isModelPopupPresented = false
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
        let secret = credentialStore.secret(for: state.selectedProviderID)
        let result = await catalog.listModels(state.selectedProviderID, secret, cachePreference, .shared)
        state.catalogModels = result.models
        state.catalogError = result.errorHint
        reconcileModelSelection(allowAutoSelect: allowAutoSelect)
        refreshStoredContextUsage()
        onModelSelectionChanged?()
        refreshInputCapabilities()
    }

    private func refreshInputCapabilities() {
        guard let modelID = state.selectedModelID else {
            state.inputCapabilities = nil
            state.isLoadingInputCapabilities = false
            return
        }
        guard state.hasAPIKey else {
            state.inputCapabilities = ModelInputCapabilities(inputModalities: [.text])
            state.isLoadingInputCapabilities = false
            return
        }
        let catalogModel = state.catalogModels.first { $0.id == modelID }
        capabilityFetchTask?.cancel()
        state.isLoadingInputCapabilities = true
        let providerID = state.selectedProviderID
        let secret = credentialStore.secret(for: providerID)
        capabilityFetchTask = Task { [weak self] in
            let caps = await self?.capabilityClient.fetchCapabilities(
                providerID, modelID, secret, catalogModel, .shared
            )
            guard !Task.isCancelled, let self, let caps else { return }
            state.inputCapabilities = caps
            state.isLoadingInputCapabilities = false
            onInputCapabilitiesResolved?(caps)
        }
    }

    private func reconcileModelSelection(allowAutoSelect: Bool) {
        let models = state.catalogModels
        guard !models.isEmpty else {
            clearSelectedModelIfNeeded()
            return
        }

        if let selectedModelID = state.selectedModelID,
           models.contains(where: { $0.id == selectedModelID }) {
            if let option = state.selectedModelOption {
                reconcileReasoningSelection(for: option)
            }
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

        if let option = state.selectedModelOption {
            if !option.availableSpeedModes.contains(state.speedMode) {
                state.speedMode = .standard
            }
            reconcileReasoningSelection(for: option)
        }
    }

    private func clearSelectedModelIfNeeded() {
        guard state.selectedModelID != nil else { return }
        state.selectedModelID = nil
        providerPreference.setModelID(nil)
    }

    private func reconcileReasoningSelection(for option: HomeModelOption) {
        let resolved = option.resolvedReasoningEffort(storedWireValue: state.reasoningEffortWireValue)
        guard resolved.wireValue != state.reasoningEffortWireValue else { return }
        providerPreference.setReasoningEffort(resolved)
        state.reasoningEffortWireValue = resolved.wireValue
    }

    private func refreshStoredContextUsage() {
        refreshContextUsage(messages: contextMessages, draftMessage: contextDraft)
    }
}
