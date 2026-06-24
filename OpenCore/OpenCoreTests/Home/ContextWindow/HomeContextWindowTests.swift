import Foundation
import Testing

@testable import OpenCore

@MainActor
@Suite("Home Context Window")
struct HomeContextWindowTests {
    @Test("Refresh reflects messages, draft, and selected model limit")
    func refreshReflectsConversationAndModel() async {
        let preference = SidePanelInMemoryProviderPreferenceStore(
            preference: SidePanelProviderPreference(
                modelID: "meta-llama/llama-3.3-70b-instruct:free"
            )
        )
        let home = HomeFlowController(
            catalog: .preview,
            credentialStore: SidePanelInMemoryCredentialStore(),
            providerPreference: preference
        )

        await home.onAppear()

        home.refreshContextUsage(
            messages: [.text(role: .user, content: String(repeating: "a", count: 400))],
            draftMessage: "draft"
        )

        #expect(home.state.contextUsage.tokenLimit == 131_072)
        #expect(home.state.contextUsage.tokensUsed == 102)
    }

    @Test("Model selection updates token limit without clearing used estimate")
    func modelSelectionUpdatesLimit() async {
        let preference = SidePanelInMemoryProviderPreferenceStore(
            preference: SidePanelProviderPreference(
                providerID: SidePanelProviderAPI.openRouter.id,
                modelID: "meta-llama/llama-3.3-70b-instruct:free"
            )
        )
        let home = HomeFlowController(
            catalog: .preview,
            credentialStore: SidePanelInMemoryCredentialStore(),
            providerPreference: preference
        )
        await home.onAppear()

        let messages: [ChatMessage] = [.text(role: .user, content: String(repeating: "a", count: 400))]
        home.refreshContextUsage(messages: messages, draftMessage: "")
        let usedBefore = home.state.contextUsage.tokensUsed
        let fractionBefore = home.state.contextUsage.fractionUsed

        home.selectModel("deepseek/deepseek-r1:free")
        home.refreshContextUsage(messages: messages, draftMessage: "")

        #expect(home.state.contextUsage.tokensUsed == usedBefore)
        #expect(home.state.contextUsage.tokenLimit == 163_840)
        #expect(home.state.contextUsage.fractionUsed < fractionBefore)
    }
}
