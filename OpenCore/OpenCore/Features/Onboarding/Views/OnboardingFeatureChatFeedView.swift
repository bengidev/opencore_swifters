import SwiftUI

enum OnboardingChatFeedTiming {
    static let firstMessageDelay: Duration = .milliseconds(350)
    static let thinkingDuration: Duration = .milliseconds(1100)
    static let afterAssistantDelay: Duration = .milliseconds(1300)

    /// How long the column eases when a row is inserted or a reply grows.
    static let placementDuration: Duration = .milliseconds(480)
    /// Stay hidden until that ease has opened the new slot.
    static let revealDelay: Duration = placementDuration
    static let revealDuration: Duration = .milliseconds(280)
    /// Next row starts only after the current placement ease has finished,
    /// so a new layout animation does not retarget the one still in flight.
    static let afterUserDelay: Duration = placementDuration

    /// Shared ease for the feed shifting up, a reply growing in place, and the
    /// thinking-to-reply crossfade. No bounce — a spring overshoot reads as a snap.
    static let placement = Animation.smooth(
        duration: timeInterval(from: placementDuration),
        extraBounce: 0
    )
    static let reveal = Animation.smooth(
        duration: timeInterval(from: revealDuration),
        extraBounce: 0
    )

    private static func timeInterval(from duration: Duration) -> TimeInterval {
        let (seconds, attoseconds) = duration.components
        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1_000_000_000_000_000_000
    }
}

/// Alternating left/right chat feed — user prompts on the right, thinking orbs that
/// become feature replies on the left, pins to the bottom and eases upward, and loops forever while active.
struct OnboardingFeatureChatFeedView: View {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: messageSpacing) {
                    ForEach(feedItems) { message in
                        OnboardingChatBubbleView(
                            message: message,
                            containerWidth: geometry.size.width,
                            animatesAppearance: true
                        )
                        .id(message.id)
                        .transition(.identity)
                    }
                }
                .layoutPriority(1)
                .padding(.vertical, 6)
                .geometryGroup()
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
            .compositingGroup()
            .clipped()
            .animation(OnboardingChatFeedTiming.placement, value: feedLayoutToken)
            .mask(feedEdgeFade)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(currentFeatureAccessibilityLabel)
        .accessibilityAdjustableAction { direction in
            nudgeFeed(by: direction == .increment ? 1 : -1)
        }
    }

    private var feedLayoutToken: String {
        feedItems.map { message in
            let role: String
            switch message.role {
            case .user:
                role = "u"
            case .thinking:
                role = "t"
            case .assistant:
                role = "a"
            }
            return "\(message.id.uuidString)-\(role)"
        }.joined(separator: "|")
    }

    private var feedEdgeFade: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.1),
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
                            animatesAppearance: false
                        )
                        OnboardingChatBubbleView(
                            message: .assistant(feature: feature),
                            containerWidth: geometry.size.width,
                            animatesAppearance: false
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
            feedItems.append(.user(prompt: feature.userPrompt, feature: feature))
            trimFeedIfNeeded()
            feedStep = .thinking
            guard await sleepUnlessCancelled(for: OnboardingChatFeedTiming.afterUserDelay) else { return }

        case .thinking:
            feedItems.append(.thinking(feature: feature))
            trimFeedIfNeeded()
            feedStep = .morph
            guard await sleepUnlessCancelled(for: OnboardingChatFeedTiming.thinkingDuration) else { return }

        case .morph:
            if let thinkingIndex = feedItems.lastIndex(where: { $0.role == .thinking }) {
                // An explicit transaction drives the opacity crossfade. The layout
                // ease on `feedLayoutToken` does not, by itself, animate that swap.
                withAnimation(OnboardingChatFeedTiming.placement) {
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
