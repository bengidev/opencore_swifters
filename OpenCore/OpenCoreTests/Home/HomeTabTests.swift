import Foundation
import Testing

@testable import OpenCore

@MainActor
@Suite("Home Tab")
struct HomeTabTests {
    private func makeHome() -> HomeFlowController {
        HomeFlowController(
            credentialStore: CredentialInMemoryStore(),
            providerPreference: SidePanelInMemoryProviderPreferenceStore()
        )
    }

    @Test("Default selected tab is home")
    func defaultTabIsHome() {
        let home = makeHome()
        #expect(home.state.selectedTab == .home)
    }

    @Test("selectTab updates selected tab")
    func selectTabUpdatesState() {
        let home = makeHome()
        home.selectTab(.settings)
        #expect(home.state.selectedTab == .settings)
        home.selectTab(.about)
        #expect(home.state.selectedTab == .about)
    }

    @Test("openSettingsTab selects settings")
    func openSettingsTabSelectsSettings() {
        let home = makeHome()
        home.openSettingsTab()
        #expect(home.state.selectedTab == .settings)
    }
}
