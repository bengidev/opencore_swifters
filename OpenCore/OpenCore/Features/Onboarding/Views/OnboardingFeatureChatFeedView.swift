import SwiftUI

enum OnboardingChatFeedTiming {
    static let firstMessageDelay: Duration = .milliseconds(350)
    static let afterUserDelay: Duration = .milliseconds(450)
    static let thinkingDuration: Duration = .milliseconds(1100)
    static let afterAssistantDelay: Duration = .milliseconds(1300)
}

/// Alternating left/right chat feed — user prompts on the right, thinking orbs that morph
/// into feature replies on the left, auto-scrolls upward, and loops forever while active.
struct OnboardingFeatureChatFeedView: View {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var bubbleNamespace

    @State private var feedItems: [OnboardingChatMessage] = []
    @State private var nextFeatureIndex = 0
    @State private var focusedFeatureIndex = 0
    @State private var accessibilityFeatureIndex = 0
    @State private var feedStep: FeedStep = .user
    @State private var feedTask: Task<Void, Never>?

    private let messageSpacing: CGFloat = 10
    private let maxVisibleItems = 20

    private enum FeedStep {
        case user
        case thinking
        case morph
    }

    var body: some View {
        Group {
            if reduceMotion {
                staticConversation
            } else {
                scrollingConversation
            }
        }
        .onAppear {
            if isActive {
                activateFeedIfNeeded()
            }
        }
        .onChange(of: isActive) { _, active in
            if active {
                activateFeedIfNeeded()
            } else {
                stopFeedLoop()
            }
        }
        .onDisappear {
            stopFeedLoop()
        }
    }

    // MARK: - Animated Feed

    private var scrollingConversation: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: messageSpacing) {
                        ForEach(feedItems) { message in
                            OnboardingChatBubbleView(
                                message: message,
                                containerWidth: geometry.size.width,
                                bubbleNamespace: bubbleNamespace
                            )
                            .id(message.id)
                            .transition(chatTransition(for: message.role))
                        }
                    }
                    .padding(.vertical, 6)
                }
                .mask(feedEdgeFade)
                .onChange(of: feedItems.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: feedItems.last?.role) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(currentFeatureAccessibilityLabel)
        .accessibilityAdjustableAction { direction in
            nudgeFeed(by: direction == .increment ? 1 : -1)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastID = feedItems.last?.id else { return }
        if reduceMotion {
            proxy.scrollTo(lastID, anchor: .bottom)
        } else {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }

    private func chatTransition(for role: OnboardingChatRole) -> AnyTransition {
        let edge: Edge = role == .user ? .trailing : .leading
        return .asymmetric(
            insertion: .move(edge: edge)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.96)),
            removal: .opacity
        )
    }

    private var feedEdgeFade: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.08),
                .init(color: .black, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Reduced Motion Fallback

    private var staticConversation: some View {
        let catalog = OnboardingFeature.catalog
        let feature = catalog.isEmpty ? nil : catalog[OnboardingFeature.wrappedCatalogIndex(focusedFeatureIndex)]

        return GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: messageSpacing) {
                    if let feature {
                        OnboardingChatBubbleView(
                            message: .user(prompt: feature.userPrompt, feature: feature),
                            containerWidth: geometry.size.width,
                            bubbleNamespace: bubbleNamespace
                        )
                        OnboardingChatBubbleView(
                            message: .assistant(feature: feature),
                            containerWidth: geometry.size.width,
                            bubbleNamespace: bubbleNamespace
                        )
                    }
                }
                .padding(.vertical, 6)
            }
            .mask(feedEdgeFade)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(currentFeatureAccessibilityLabel)
        .accessibilityAdjustableAction { direction in
            nudgeFocusedFeature(by: direction == .increment ? 1 : -1)
        }
    }

    // MARK: - Feed Loop

    private func activateFeedIfNeeded(preserveFeatureIndex: Bool = false) {
        guard !reduceMotion else { return }
        startFeedLoop(preserveFeatureIndex: preserveFeatureIndex)
    }

    private func startFeedLoop(preserveFeatureIndex: Bool = false) {
        stopFeedLoop()
        feedItems = []
        feedStep = .user
        if !preserveFeatureIndex {
            nextFeatureIndex = 0
            accessibilityFeatureIndex = 0
        }

        feedTask = Task {
            guard await sleepUnlessCancelled(for: OnboardingChatFeedTiming.firstMessageDelay) else { return }

            while !Task.isCancelled, isActive {
                await advanceFeed()
            }
        }
    }

    private func stopFeedLoop() {
        feedTask?.cancel()
        feedTask = nil
    }

    @MainActor
    private func advanceFeed() async {
        let catalog = OnboardingFeature.catalog
        guard !catalog.isEmpty else { return }

        let feature = catalog[nextFeatureIndex]

        switch feedStep {
        case .user:
            accessibilityFeatureIndex = nextFeatureIndex
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                feedItems.append(.user(prompt: feature.userPrompt, feature: feature))
                trimFeedIfNeeded()
            }
            feedStep = .thinking
            guard await sleepUnlessCancelled(for: OnboardingChatFeedTiming.afterUserDelay) else { return }

        case .thinking:
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                feedItems.append(.thinking(feature: feature))
                trimFeedIfNeeded()
            }
            feedStep = .morph
            guard await sleepUnlessCancelled(for: OnboardingChatFeedTiming.thinkingDuration) else { return }

        case .morph:
            if let thinkingIndex = feedItems.lastIndex(where: { $0.role == .thinking }) {
                withAnimation(.spring(response: 0.62, dampingFraction: 0.84)) {
                    feedItems[thinkingIndex] = feedItems[thinkingIndex].morphToAssistant()
                }
            }
            nextFeatureIndex = (nextFeatureIndex + 1) % catalog.count
            feedStep = .user
            guard await sleepUnlessCancelled(for: OnboardingChatFeedTiming.afterAssistantDelay) else { return }
        }
    }

    @MainActor
    private func trimFeedIfNeeded() {
        guard feedItems.count > maxVisibleItems else { return }
        feedItems.removeFirst(feedItems.count - maxVisibleItems)
    }

    @MainActor
    private func sleepUnlessCancelled(for duration: Duration) async -> Bool {
        do {
            try await Task.sleep(for: duration)
        } catch {
            return false
        }
        return !Task.isCancelled && isActive
    }

    private var currentFeatureAccessibilityLabel: String {
        let catalog = OnboardingFeature.catalog
        guard !catalog.isEmpty else { return "Onboarding features" }

        let index = reduceMotion ? focusedFeatureIndex : accessibilityFeatureIndex
        return catalog[OnboardingFeature.wrappedCatalogIndex(index)].feedAccessibilityLabel
    }

    private func nudgeFeed(by delta: Int) {
        let catalog = OnboardingFeature.catalog
        guard !catalog.isEmpty else { return }

        stopFeedLoop()
        let current = OnboardingFeature.wrappedCatalogIndex(accessibilityFeatureIndex)
        let target = OnboardingFeature.wrappedCatalogIndex(current + delta)
        nextFeatureIndex = target
        accessibilityFeatureIndex = target
        feedStep = .user
        feedItems = []

        if isActive {
            activateFeedIfNeeded(preserveFeatureIndex: true)
        }
    }

    private func nudgeFocusedFeature(by delta: Int) {
        let count = OnboardingFeature.catalog.count
        guard count > 0 else { return }
        focusedFeatureIndex = OnboardingFeature.wrappedCatalogIndex(focusedFeatureIndex + delta)
    }
}
