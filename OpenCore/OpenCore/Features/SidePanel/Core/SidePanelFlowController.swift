import Foundation
import Observation

/// Host flow controller for the side panel. Composes the session browser
/// (`SidePanelSessionFlowController`) and the settings sheet
/// (`SidePanelSettingFlowController`) and wires their delegate closures
/// to the host's own outputs so the parent (Home/AppRoot) receives a
/// single set of callbacks.
///
/// The host does not need its own FlowState — it composes the
/// sub-controllers' states. It is `@Observable` so SwiftUI views can
/// observe `setting` presence and `isSidebarVisible`.
@MainActor
@Observable
final class SidePanelFlowController {
    /// The session sub-controller (conversation list + sidebar).
    let session: SidePanelSessionFlowController

    /// Presented settings sheet. `nil` when the sheet is dismissed.
    private(set) var setting: SidePanelSettingFlowController?

    /// Whether the parent's selected model supports reasoning. Mirrored from
    /// Home so the settings sheet can gate the reasoning control.
    var modelSupportsReasoning = false

    /// The currently selected provider id, mirrored from Home. Defaults to
    /// the catalog default so the control always has a valid selection.
    private(set) var selectedProviderID: String

    /// Convenience mirror of the session scope's sidebar visibility, so the
    /// parent and views can read it without reaching into the sub-scope.
    var isSidebarVisible: Bool { session.state.isSidebarVisible }

    // MARK: - Stores (held for settings presentation)

    private let credentialStore: any SidePanelCredentialStore
    private let providerPreference: any SidePanelProviderPreferenceStore

    // MARK: - Delegate outputs (surfaced to parent)

    var onOpenConversation: ((SidePanelConversation) -> Void)?
    var onActiveConversationRenamed: ((UUID, String) -> Void)?
    var onActiveConversationDeleted: ((UUID) -> Void)?
    var onCredentialsChanged: (() -> Void)?
    var onReasoningModelChanged: (() -> Void)?
    var onProviderChanged: ((String) -> Void)?

    // MARK: - Init

    init(
        session: SidePanelSessionFlowController = .init(),
        credentialStore: any SidePanelCredentialStore,
        providerPreference: any SidePanelProviderPreferenceStore
    ) {
        self.session = session
        self.credentialStore = credentialStore
        self.providerPreference = providerPreference
        self.selectedProviderID = SidePanelProviderAPI.default.id

        // Wire session delegate forwards.
        session.onOpenConversation = { [weak self] convo in
            self?.onOpenConversation?(convo)
        }
        session.onActiveConversationRenamed = { [weak self] id, title in
            self?.onActiveConversationRenamed?(id, title)
        }
        session.onActiveConversationDeleted = { [weak self] id in
            self?.onActiveConversationDeleted?(id)
        }
    }

    // MARK: - Settings presentation

    /// Present the settings sheet, seeding it with current store state.
    func settingsButtonTapped() {
        let providerID = selectedProviderID
        let prefs = providerPreference.preference()

        let settingController = SidePanelSettingFlowController(
            state: SidePanelSettingFlowState(
                hasStoredKey: credentialStore.secret(for: providerID) != nil,
                reasoningModel: prefs.reasoningModel,
                modelSupportsReasoning: modelSupportsReasoning,
                selectedProviderID: providerID
            ),
            credentialStore: credentialStore,
            providerPreference: providerPreference
        )

        settingController.onCredentialsChanged = { [weak self] in
            guard let self else { return }
            self.selectedProviderID = self.providerPreference.preference().providerID
                ?? SidePanelProviderAPI.default.id
            self.onCredentialsChanged?()
        }

        settingController.onReasoningModelChanged = { [weak self] in
            self?.onReasoningModelChanged?()
        }

        settingController.onProviderChanged = { [weak self] id in
            guard let self else { return }
            self.selectedProviderID = self.providerPreference.preference().providerID
                ?? SidePanelProviderAPI.default.id
            self.onProviderChanged?(id)
        }

        setting = settingController
    }

    /// Dismiss the settings sheet and notify the parent that credentials
    /// may have changed (matching TCA `.setting(.dismiss)` behavior).
    func dismissSettings() {
        setting = nil
        onCredentialsChanged?()
    }

    /// Called by the parent when the selected model changes so the
    /// reasoning gate can be refreshed.
    func setModelSupportsReasoning(_ value: Bool) {
        modelSupportsReasoning = value
    }
}
