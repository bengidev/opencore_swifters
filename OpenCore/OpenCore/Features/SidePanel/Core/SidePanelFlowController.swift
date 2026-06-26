import Foundation
import Observation

/// Host flow controller for the side panel. Composes the session browser
/// (`SidePanelSessionFlowController`) and the fullscreen settings page
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

    /// Presented settings page. `nil` when settings are dismissed.
    private(set) var setting: SidePanelSettingFlowController?

    /// The currently selected provider id, mirrored from Home. Defaults to
    /// the catalog default so the control always has a valid selection.
    private(set) var selectedProviderID: String

    /// Convenience mirror of the session scope's sidebar visibility, so the
    /// parent and views can read it without reaching into the sub-scope.
    var isSidebarVisible: Bool { session.state.isSidebarVisible }

    // MARK: - Stores (held for settings presentation)

    private let credentialStore: any CredentialStoring
    private let providerPreference: any SidePanelProviderPreferenceStore

    // MARK: - Delegate outputs (surfaced to parent)

    var onOpenConversation: ((SidePanelConversation) -> Void)?
    var onActiveConversationRenamed: ((UUID, String) -> Void)?
    var onActiveConversationDeleted: ((UUID) -> Void)?
    var onCredentialsChanged: (() -> Void)?
    var onProviderChanged: ((String) -> Void)?

    // MARK: - Init

    init(
        session: SidePanelSessionFlowController = .init(),
        credentialStore: any CredentialStoring,
        providerPreference: any SidePanelProviderPreferenceStore
    ) {
        self.session = session
        self.credentialStore = credentialStore
        self.providerPreference = providerPreference
        self.selectedProviderID = ProviderDescriptor.openRouter.id

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
        session.onSettingsTapped = { [weak self] in
            self?.settingsButtonTapped()
        }
    }

    // MARK: - Settings presentation

    /// Present the settings page, seeding it with current store state.
    func settingsButtonTapped() {
        let providerID = selectedProviderID

        let settingController = SidePanelSettingFlowController(
            state: SidePanelSettingFlowState(
                hasStoredKey: credentialStore.secret(for: providerID) != nil,
                selectedProviderID: providerID
            ),
            credentialStore: credentialStore,
            providerPreference: providerPreference
        )

        settingController.onCredentialsChanged = { [weak self] in
            guard let self else { return }
            self.selectedProviderID = self.providerPreference.preference().providerID
                ?? ProviderDescriptor.openRouter.id
            self.onCredentialsChanged?()
        }

        settingController.onProviderChanged = { [weak self] id in
            guard let self else { return }
            self.selectedProviderID = self.providerPreference.preference().providerID
                ?? ProviderDescriptor.openRouter.id
            self.onProviderChanged?(id)
        }

        setting = settingController
    }

    /// Dismiss the settings page and notify the parent that credentials
    /// may have changed (on settings dismiss).
    func dismissSettings() {
        setting = nil
        onCredentialsChanged?()
    }
}
