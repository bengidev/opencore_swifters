import Foundation
import Testing

@testable import OpenCore

@MainActor
@Suite("Home Popup Presentation")
struct HomePopupPresentationTests {
    private func makeHome() -> HomeFlowController {
        HomeFlowController(
            credentialStore: CredentialInMemoryStore(),
            providerPreference: SidePanelInMemoryProviderPreferenceStore()
        )
    }

    @Test("Opening context usage closes model popup")
    func contextUsageClosesModelPopup() {
        let home = makeHome()
        home.setModelPopupPresented(true)

        home.setContextUsagePresented(true)

        #expect(home.state.isContextUsagePresented)
        #expect(!home.state.isModelPopupPresented)
    }

    @Test("Opening model popup closes context usage")
    func modelPopupClosesContextUsage() {
        let home = makeHome()
        home.setContextUsagePresented(true)

        home.setModelPopupPresented(true)

        #expect(home.state.isModelPopupPresented)
        #expect(!home.state.isContextUsagePresented)
    }
}
