import SwiftUI

/// Root home screen — welcome state or active chat thread with composer.
struct HomeView: View {
    @Bindable var sidePanel: SidePanelFlowController
    @Bindable var home: HomeFlowController
    @Bindable var chat: ChatFlowController

    @FocusState private var isComposerFocused: Bool

    @Environment(\.sharedPalette) private var palette

    private var showsWelcome: Bool {
        !chat.state.hasMessages
    }

    var body: some View {
        ZStack {
            palette.surfaceBase
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissComposerKeyboard()
                    }

                if showsWelcome {
                    welcomeContent
                } else {
                    chatThreadContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(sidePanel.isSidebarVisible)

            SidePanelView(flow: sidePanel)
        }
        .onAppear {
            wireDelegates()
        }
        .task {
            await home.onAppear()
            syncSidePanelFromHome()
            refreshContextUsage()
        }
        .onChange(of: chat.state.messages) { _, _ in
            refreshContextUsage()
        }
        .onChange(of: chat.state.draftMessage) { _, _ in
            refreshContextUsage()
        }
        .sheet(isPresented: Binding(
            get: { home.state.isModelPopupPresented },
            set: { home.setModelPopupPresented($0) }
        )) {
            HomeModelPopupView(home: home)
        }
    }

    private var welcomeContent: some View {
        WelcomeScrollContainer(
            isComposerFocused: isComposerFocused,
            dismissKeyboard: dismissComposerKeyboard
        ) { viewportHeight in
            HomeWelcomeView(viewportHeight: viewportHeight)
        } composer: {
            composer
        }
    }

    private var chatThreadContent: some View {
        VStack(spacing: 0) {
            if let conversation = chat.state.conversation {
                Text(conversation.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }

            ChatThreadView(flow: chat)
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissComposerKeyboard()
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                ChatErrorBannerView(flow: chat)
                    .animation(.easeInOut(duration: 0.2), value: chat.state.streamingStatus)

                composer
            }
        }
    }

    private var composer: some View {
        HomeComposerView(
            home: home,
            chat: chat,
            isComposerFocused: $isComposerFocused
        )
    }

    private var topBar: some View {
        HStack {
            Button {
                sidePanel.session.mirrorActiveConversationID(chat.state.conversation?.id)
                Task { await sidePanel.session.toggleSidebar() }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(palette.textPrimary)
            }
            .accessibilityLabel("Show sidebar")

            Spacer()

            Button {
                dismissComposerKeyboard()
                chat.clearActiveConversation()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(palette.textPrimary)
            }
            .accessibilityLabel("New conversation")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func wireDelegates() {
        home.onOpenSettings = {
            sidePanel.settingsButtonTapped()
        }
        home.onModelSelectionChanged = {
            syncSidePanelFromHome()
            refreshContextUsage()
        }

        sidePanel.onOpenConversation = { conversation in
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
        sidePanel.onCredentialsChanged = {
            home.handleCredentialsChanged()
        }
        sidePanel.onReasoningModelChanged = {
            home.handleReasoningModelChanged()
        }
        sidePanel.onProviderChanged = { providerID in
            Task { await home.handleProviderChanged(providerID) }
        }
    }

    private func syncSidePanelFromHome() {
        sidePanel.setModelSupportsReasoning(home.state.selectedModelOption?.supportsReasoning == true)
    }

    private func refreshContextUsage() {
        home.refreshContextUsage(
            messages: chat.state.messages,
            draftMessage: chat.state.draftMessage
        )
    }

    private func dismissComposerKeyboard() {
        isComposerFocused = false
    }
}

private enum HomeScrollAnchor: Hashable {
    case welcomeTop
    case welcomeBottom
}

private struct WelcomeScrollContainer<Content: View, Composer: View>: View {
    let isComposerFocused: Bool
    let dismissKeyboard: () -> Void
    @ViewBuilder let content: (_ viewportHeight: CGFloat) -> Content
    @ViewBuilder let composer: () -> Composer

    @State private var viewportHeight: CGFloat = 0
    @State private var pendingScrollWork: DispatchWorkItem?

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                Color.clear
                    .frame(height: 1)
                    .id(HomeScrollAnchor.welcomeTop)

                content(viewportHeight)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: viewportHeight > 0 ? viewportHeight : nil)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissKeyboard()
                    }

                Color.clear
                    .frame(height: 1)
                    .id(HomeScrollAnchor.welcomeBottom)
            }
            .scrollDismissesKeyboard(.interactively)
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: WelcomeViewportHeightKey.self,
                            value: geometry.size.height
                        )
                }
            }
            .onPreferenceChange(WelcomeViewportHeightKey.self) { viewportHeight = $0 }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                composer()
            }
            .onChange(of: isComposerFocused) { _, isFocused in
                if isFocused {
                    scheduleWelcomeScroll(
                        to: .welcomeBottom,
                        scrollAnchor: .bottom,
                        delay: HomeWelcomeLayoutMetrics.welcomeScrollDelay,
                        with: scrollProxy
                    )
                } else {
                    scheduleWelcomeScroll(
                        to: .welcomeTop,
                        scrollAnchor: .top,
                        delay: 0,
                        with: scrollProxy
                    )
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                scheduleWelcomeScroll(
                    to: .welcomeTop,
                    scrollAnchor: .top,
                    delay: 0,
                    with: scrollProxy
                )
            }
        }
    }

    private func scheduleWelcomeScroll(
        to anchor: HomeScrollAnchor,
        scrollAnchor: UnitPoint,
        delay: TimeInterval,
        with proxy: ScrollViewProxy
    ) {
        pendingScrollWork?.cancel()
        let work = DispatchWorkItem {
            withAnimation(HomeWelcomeLayoutMetrics.welcomeAnimation) {
                proxy.scrollTo(anchor, anchor: scrollAnchor)
            }
        }
        pendingScrollWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}

private struct WelcomeViewportHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    let credentialStore = SidePanelInMemoryCredentialStore()
    let providerPreference = SidePanelInMemoryProviderPreferenceStore(
        preference: SidePanelProviderPreference(modelID: "meta-llama/llama-3.3-70b-instruct:free")
    )
    return HomeView(
        sidePanel: SidePanelFlowController(
            credentialStore: credentialStore,
            providerPreference: providerPreference
        ),
        home: HomeFlowController(
            credentialStore: credentialStore,
            providerPreference: providerPreference
        ),
        chat: ChatFlowController(providerPreference: providerPreference)
    )
    .environment(\.sharedPalette, SharedOpenCorePalette.resolve(.light))
}
