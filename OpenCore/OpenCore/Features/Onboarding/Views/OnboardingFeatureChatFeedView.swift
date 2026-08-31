import SwiftUI

/// Alternating left/right chat feed — user prompts on the right, thinking orbs that morph
/// into feature replies on the left, auto-scrolls upward, and loops forever while active.
struct OnboardingFeatureChatFeedView: View {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var feedItems: [OnboardingChatMessage] = []
    @State private var nextFeatureIndex = 0
    @State private var feedStep: FeedStep = .user
    @State private var feedTask: Task<Void, Never>?

    private let messageSpacing: CGFloat = 10
    private let maxVisibleItems = 20
    private let firstMessageDelay: Duration = .milliseconds(350)
    private let afterUserDelay: Duration = .milliseconds(450)
    private let thinkingDuration: Duration = .milliseconds(1100)
    private let afterAssistantDelay: Duration = .milliseconds(1300)

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
                startFeedLoop()
            }
        }
        .onChange(of: isActive) { _, active in
            if active {
                startFeedLoop()
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
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: messageSpacing) {
                    ForEach(feedItems) { message in
                        OnboardingChatBubbleView(message: message)
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

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastID = feedItems.last?.id else { return }
        withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
            proxy.scrollTo(lastID, anchor: .bottom)
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
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: messageSpacing) {
                ForEach(OnboardingFeature.catalog) { feature in
                    OnboardingChatBubbleView(message: .user(prompt: feature.userPrompt, feature: feature))
                    OnboardingChatBubbleView(message: .assistant(feature: feature))
                }
            }
            .padding(.vertical, 6)
        }
        .mask(feedEdgeFade)
    }

    // MARK: - Feed Loop

    private func startFeedLoop() {
        stopFeedLoop()
        feedItems = []
        nextFeatureIndex = 0
        feedStep = .user

        feedTask = Task {
            try? await Task.sleep(for: firstMessageDelay)
            guard !Task.isCancelled, isActive else { return }

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
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                feedItems.append(.user(prompt: feature.userPrompt, feature: feature))
                trimFeedIfNeeded()
            }
            feedStep = .thinking
            try? await Task.sleep(for: afterUserDelay)

        case .thinking:
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                feedItems.append(.thinking(feature: feature))
                trimFeedIfNeeded()
            }
            feedStep = .morph
            try? await Task.sleep(for: thinkingDuration)

        case .morph:
            if let thinkingIndex = feedItems.lastIndex(where: { $0.role == .thinking }) {
                withAnimation(.spring(response: 0.62, dampingFraction: 0.84)) {
                    feedItems[thinkingIndex] = feedItems[thinkingIndex].morphToAssistant()
                }
            }
            nextFeatureIndex = (nextFeatureIndex + 1) % catalog.count
            feedStep = .user
            try? await Task.sleep(for: afterAssistantDelay)
        }
    }

    @MainActor
    private func trimFeedIfNeeded() {
        guard feedItems.count > maxVisibleItems else { return }
        feedItems.removeFirst(feedItems.count - maxVisibleItems)
    }
}
