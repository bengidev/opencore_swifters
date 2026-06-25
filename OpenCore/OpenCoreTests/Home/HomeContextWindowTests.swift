import Foundation
import Testing

@testable import OpenCore

@MainActor
@Suite("Home Context Window")
struct HomeContextWindowTests {
    @Test("Catalog fetch applies selected model context limit")
    func catalogFetchAppliesContextLimit() async {
        let preference = SidePanelInMemoryProviderPreferenceStore(
            preference: SidePanelProviderPreference(
                modelID: "meta-llama/llama-3.3-70b-instruct:free"
            )
        )
        let home = HomeFlowController(
            catalog: HomeTestCatalog.client,
            credentialStore: HomeTestCatalog.credentialStoreWithKey(),
            providerPreference: preference
        )

        home.refreshContextUsage(messages: [], draftMessage: "")
        #expect(home.state.contextUsage.tokenLimit == 0)

        await home.onAppear()
        home.refreshContextUsage(messages: [], draftMessage: "")

        #expect(home.state.contextUsage.tokenLimit == 131_072)
    }

    @Test("Credentials change reloads catalog and updates context limit")
    func credentialsChangeReloadsCatalog() async {
        let credentialStore = CredentialInMemoryStore()
        let preference = SidePanelInMemoryProviderPreferenceStore()
        let home = HomeFlowController(
            catalog: HomeTestCatalog.client,
            credentialStore: credentialStore,
            providerPreference: preference
        )

        await home.onAppear()
        home.refreshContextUsage(messages: [], draftMessage: "")
        #expect(home.state.contextUsage.tokenLimit == 0)

        try? credentialStore.save("test-key", for: ProviderDescriptor.openRouter.id)
        await home.handleCredentialsChanged()
        home.refreshContextUsage(messages: [], draftMessage: "")

        #expect(!home.state.catalogModels.isEmpty)
        #expect(home.state.contextUsage.tokenLimit == 131_072)
    }

    @Test("Refresh reflects messages, draft, and selected model limit")
    func refreshReflectsConversationAndModel() async {
        let preference = SidePanelInMemoryProviderPreferenceStore(
            preference: SidePanelProviderPreference(
                modelID: "meta-llama/llama-3.3-70b-instruct:free"
            )
        )
        let home = HomeFlowController(
            catalog: HomeTestCatalog.client,
            credentialStore: HomeTestCatalog.credentialStoreWithKey(),
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
                providerID: ProviderDescriptor.openRouter.id,
                modelID: "meta-llama/llama-3.3-70b-instruct:free"
            )
        )
        let home = HomeFlowController(
            catalog: HomeTestCatalog.client,
            credentialStore: HomeTestCatalog.credentialStoreWithKey(
                for: ProviderDescriptor.openRouter.id
            ),
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
