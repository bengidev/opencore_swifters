import SwiftUI

/// Root home screen — welcome state or active chat thread with composer.
struct HomeView: View {
    @Bindable var sidePanel: SidePanelFlowController
    @Bindable var chat: ChatFlowController

    @State private var speedMode = HomeVisualDefaults.speedMode
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

            SidePanelView(flow: sidePanel)
        }
        .onAppear {
            wireSidePanelDelegates()
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
            draftMessage: Binding(
                get: { chat.state.draftMessage },
                set: { chat.setDraftMessage($0) }
            ),
            speedMode: $speedMode,
            selectedModelTitle: HomeVisualDefaults.selectedModelTitle,
            contextUsage: HomeVisualDefaults.contextUsage,
            availableSpeedModes: HomeVisualDefaults.availableSpeedModes,
            isSendEnabled: !chat.state.isSending,
            onSend: {
                Task { await chat.sendMessage() }
            },
            isComposerFocused: $isComposerFocused
        )
    }

    private var topBar: some View {
        HStack {
            Button {
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

    private func wireSidePanelDelegates() {
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
    HomeView(
        sidePanel: SidePanelFlowController(
            credentialStore: SidePanelInMemoryCredentialStore(),
            providerPreference: SidePanelInMemoryProviderPreferenceStore()
        ),
        chat: ChatFlowController()
    )
    .environment(\.sharedPalette, SharedOpenZonePalette.resolve(.light))
}
