import SwiftUI

/// Tab shell composing Home, Settings, and About feature modules.
struct HomeTabShellView: View {
    @Bindable var sidePanel: SidePanelFlowController
    @Bindable var home: HomeFlowController
    @Bindable var chat: ChatFlowController
    @Bindable var settings: SettingsFlowController

    @Environment(\.sharedPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.sharedAppTheme) private var appTheme

    var body: some View {
        TabView(selection: Binding(
            get: { home.state.selectedTab },
            set: { home.selectTab($0) }
        )) {
            HomeView(sidePanel: sidePanel, home: home, chat: chat)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(HomeTab.home)

            NavigationStack {
                SettingsView(flow: settings)
            }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            .tag(HomeTab.settings)

            NavigationStack {
                AboutView()
            }
            .tabItem { Label("About", systemImage: "info.circle.fill") }
            .tag(HomeTab.about)
        }
        .tint(palette.textPrimary)
        .onAppear { SharedTabBarAppearance.applyIfNeeded(palette: palette) }
        .onChange(of: colorScheme) { _, _ in
            SharedTabBarAppearance.applyIfNeeded(palette: palette)
        }
        .onChange(of: appTheme) { _, _ in
            SharedTabBarAppearance.applyIfNeeded(palette: palette)
        }
        .task {
            wireDelegates()
        }
    }

    private func wireDelegates() {
        settings.onCredentialsChanged = {
            Task { await home.handleCredentialsChanged() }
        }
        settings.onProviderChanged = { providerID in
            Task { await home.handleProviderChanged(providerID) }
            sidePanel.syncSelectedProviderID(providerID)
        }

        sidePanel.onOpenConversation = { conversation in
            home.selectTab(.home)
            Task { await chat.reopenConversation(conversation) }
        }
        sidePanel.onActiveConversationRenamed = { id, title in
            chat.renameActiveConversation(id: id, title: title)
        }
        sidePanel.onActiveConversationDeleted = { id in
            if chat.state.conversation?.id == id {
                chat.clearActiveConversation()
            }
        }
    }
}

#Preview {
    let credentialStore = CredentialInMemoryStore()
    let providerPreference = SidePanelInMemoryProviderPreferenceStore()
    return HomeTabShellView(
        sidePanel: SidePanelFlowController(),
        home: HomeFlowController(
            credentialStore: credentialStore,
            providerPreference: providerPreference
        ),
        chat: ChatFlowController(providerPreference: providerPreference),
        settings: SettingsFlowController(
            credentialStore: credentialStore,
            providerPreference: providerPreference
        )
    )
    .environment(\.sharedPalette, SharedOpenCorePalette.resolve(.light))
}
