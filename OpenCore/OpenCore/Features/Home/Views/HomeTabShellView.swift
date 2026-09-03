import SwiftUI

/// Tab shell composing Home, Atoms, Settings, and About feature modules.
struct HomeTabShellView: View {
    @Bindable var atoms: AtomsFlowController
    @Bindable var home: HomeFlowController
    @Bindable var chat: ChatFlowController
    @Bindable var settings: SettingsFlowController
    @Bindable var speech: SpeechFlowController
    @Bindable var vision: VisionFlowController

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        TabView(selection: Binding(
            get: { home.state.selectedTab },
            set: { home.selectTab($0) }
        )) {
            HomeView(home: home, chat: chat, speech: speech, vision: vision)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(HomeTab.home)

            NavigationStack {
                AtomsListView(flow: atoms)
            }
            .tabItem { Label("Atoms", systemImage: "atom") }
            .tag(HomeTab.atoms)

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
        .background(SharedTabBarPaletteStyle(palette: palette))
        .task {
            wireDelegates()
        }
        .onChange(of: chat.state.atom?.id) { _, atomID in
            atoms.mirrorActiveAtomID(atomID)
        }
    }

    private func wireDelegates() {
        settings.onCredentialsChanged = {
            Task { await home.handleCredentialsChanged() }
        }
        settings.onProviderChanged = { providerID in
            Task { await home.handleProviderChanged(providerID) }
            atoms.syncSelectedProviderID(providerID)
        }

        home.onInputCapabilitiesResolved = { capabilities in
            guard !capabilities.supportsAttachments else { return }
            chat.clearDraftAttachments()
        }

        atoms.onOpenAtom = { atom in
            home.selectTab(.home)
            Task {
                await speech.cancelListening()
                await chat.reopenAtom(atom)
            }
        }
        atoms.onActiveAtomRenamed = { id, title in
            chat.renameActiveAtom(id: id, title: title)
        }
        atoms.onActiveAtomDeleted = { id in
            if chat.state.atom?.id == id {
                Task {
                    await speech.cancelListening()
                    chat.clearActiveAtom()
                }
            }
        }
    }
}

#Preview {
    let credentialStore = CredentialInMemoryStore()
    let providerPreference = InMemoryProviderPreferenceStore()
    HomeTabShellView(
        atoms: AtomsFlowController(),
        home: HomeFlowController(
            credentialStore: credentialStore,
            providerPreference: providerPreference
        ),
        chat: ChatFlowController(providerPreference: providerPreference),
        settings: SettingsFlowController(
            credentialStore: credentialStore,
            providerPreference: providerPreference
        ),
        speech: SpeechFlowController(),
        vision: VisionFlowController()
    )
    .environment(\.sharedPalette, SharedOpenCorePalette.resolve(.light))
}
