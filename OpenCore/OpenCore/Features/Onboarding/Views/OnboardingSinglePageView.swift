import SwiftUI

/// Single-page onboarding — one persistent cube hero animates from center to the header slot,
/// then feature cards auto-swipe in a loop and the swipe CTA staggers in.
struct OnboardingSinglePageView: View {
    var onComplete: () async -> Bool = { true }

    @Environment(\.sharedPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var cubeAppeared = false
    /// 0 = large centered hero, 1 = docked header icon with isometric pose locked.
    @State private var heroTransition: CGFloat = 0
    @State private var isTransformed = false
    @State private var showCarousel = false
    @State private var carouselRevealed = false
    @State private var swipeCompleted = false
    @State private var transitionTask: Task<Void, Never>?
    @State private var carouselMountTask: Task<Void, Never>?

    private let heroLargeSize: CGFloat = 220
    private let heroSmallSize: CGFloat = 36
    private let headerTopPadding: CGFloat = 18
    private let headerHorizontalPadding: CGFloat = 24
    private let footerBottomPadding: CGFloat = 2
    private let carouselFadeDelay: Duration = .milliseconds(780)
    /// Time the large centered cube stays on screen before the header transition begins.
    private let heroShowoffDelay: Duration = .milliseconds(1750)

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                OnboardingTransformedLayout(
                    isTransformed: isTransformed,
                    showCarousel: showCarousel,
                    carouselRevealed: carouselRevealed,
                    swipeCompleted: $swipeCompleted,
                    heroSmallSize: heroSmallSize,
                    headerTopPadding: headerTopPadding,
                    headerHorizontalPadding: headerHorizontalPadding,
                    footerBottomPadding: footerBottomPadding,
                    reduceMotion: reduceMotion,
                    headerTitleAnimation: headerTitleAnimation,
                    swipeSectionAnimation: swipeSectionAnimation,
                    carouselFadeAnimation: carouselFadeAnimation,
                    onComplete: onComplete
                )

                OnboardingHeroCubeOverlay(
                    transition: heroTransition,
                    appeared: cubeAppeared,
                    morphPaused: showCarousel && carouselRevealed,
                    containerSize: proxy.size,
                    inkColor: palette.textPrimary,
                    largeSize: heroLargeSize,
                    smallSize: heroSmallSize,
                    headerTopPadding: headerTopPadding,
                    headerHorizontalPadding: headerHorizontalPadding,
                    safeTop: 0
                )

                themeToggleSection
            }
        }
        .background {
            palette.surfaceBase
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.28), value: palette.isDark)
        }
        .onAppear {
            cubeAppeared = true
            scheduleHeroTransformation()
        }
        .onDisappear {
            transitionTask?.cancel()
            transitionTask = nil
            carouselMountTask?.cancel()
            carouselMountTask = nil
        }
    }

    private var themeToggleSection: some View {
        HStack {
            Spacer(minLength: 0)
            SharedThemeToggleButton()
                .accessibilityIdentifier("onboarding-theme-toggle")
        }
        .padding(.top, headerTopPadding)
        .padding(.horizontal, headerHorizontalPadding)
    }

    // MARK: - Hero Layout Math

    struct HeroCubeLayout {
        let size: CGFloat
        let center: CGPoint
    }

    /// Fraction of `heroTransition` where the big cube finishes rotating into the isometric pose.
    private static let heroRotationEndTransition: CGFloat = 0.38
    /// Fraction where shrink to the header begins — the gap before this is the isometric settle beat.
    private static let heroMorphStartTransition: CGFloat = 0.54

    static func heroRotationProgress(from transition: CGFloat) -> CGFloat {
        let raw = min(max(transition / heroRotationEndTransition, 0), 1)
        return 1 - pow(1 - raw, 2)
    }

    static func heroMorphProgress(from transition: CGFloat) -> CGFloat {
        let span = max(1 - heroMorphStartTransition, 0.001)
        let raw = (transition - heroMorphStartTransition) / span
        let clamped = min(max(raw, 0), 1)
        return 1 - pow(1 - clamped, 3)
    }

    static func heroCubeLayout(
        transition: CGFloat,
        in size: CGSize,
        largeSize: CGFloat,
        smallSize: CGFloat,
        headerTopPadding: CGFloat,
        headerHorizontalPadding: CGFloat,
        safeTop: CGFloat
    ) -> HeroCubeLayout {
        heroCubeLayout(
            morph: heroMorphProgress(from: transition),
            in: size,
            largeSize: largeSize,
            smallSize: smallSize,
            headerTopPadding: headerTopPadding,
            headerHorizontalPadding: headerHorizontalPadding,
            safeTop: safeTop
        )
    }

    static func heroCubeLayout(
        morph: CGFloat,
        in size: CGSize,
        largeSize: CGFloat,
        smallSize: CGFloat,
        headerTopPadding: CGFloat,
        headerHorizontalPadding: CGFloat,
        safeTop: CGFloat
    ) -> HeroCubeLayout {
        let clampedMorph = min(max(morph, 0), 1)
        let cubeSize = largeSize + (smallSize - largeSize) * clampedMorph

        let largeCenter = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        let smallCenter = CGPoint(
            x: headerHorizontalPadding + smallSize * 0.5,
            y: safeTop + headerTopPadding + smallSize * 0.5
        )

        return HeroCubeLayout(
            size: cubeSize,
            center: CGPoint(
                x: largeCenter.x + (smallCenter.x - largeCenter.x) * clampedMorph,
                y: largeCenter.y + (smallCenter.y - largeCenter.y) * clampedMorph
            )
        )
    }

    private var heroTransitionAnimation: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.35)
            : .smooth(duration: 1.02, extraBounce: 0)
    }

    // MARK: - Animation Curves

    private var headerTitleAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.25)
            : .spring(response: 0.5, dampingFraction: 0.8).delay(0.12)
    }

    private var swipeSectionAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.2)
            : .spring(response: 0.6, dampingFraction: 0.8).delay(0.62)
    }

    private var carouselFadeAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.2)
            : .spring(response: 0.58, dampingFraction: 0.78)
    }

    // MARK: - Orchestration

    private func scheduleHeroTransformation() {
        transitionTask?.cancel()
        transitionTask = Task {
            if !reduceMotion {
                try? await Task.sleep(for: heroShowoffDelay)
                guard !Task.isCancelled else { return }
            }

            await MainActor.run {
                triggerHeroTransformation()
            }
        }
    }

    @MainActor
    private func triggerHeroTransformation() {
        if reduceMotion {
            heroTransition = 1
            isTransformed = true
            scheduleCarouselAppearance()
            return
        }

        withAnimation(heroTransitionAnimation) {
            heroTransition = 1
            isTransformed = true
        }
        scheduleCarouselAppearance()
    }

    @MainActor
    private func scheduleCarouselAppearance() {
        carouselMountTask?.cancel()
        carouselMountTask = Task {
            try? await Task.sleep(for: carouselFadeDelay)
            guard !Task.isCancelled, isTransformed else { return }

            showCarousel = true
            withAnimation(carouselFadeAnimation) {
                carouselRevealed = true
            }
        }
    }
}

// MARK: - Transformed Layout (no heroMorph dependency)

private struct OnboardingTransformedLayout: View {
    let isTransformed: Bool
    let showCarousel: Bool
    let carouselRevealed: Bool
    @Binding var swipeCompleted: Bool
    let heroSmallSize: CGFloat
    let headerTopPadding: CGFloat
    let headerHorizontalPadding: CGFloat
    let footerBottomPadding: CGFloat
    let reduceMotion: Bool
    let headerTitleAnimation: Animation
    let swipeSectionAnimation: Animation
    let carouselFadeAnimation: Animation
    var onComplete: () async -> Bool

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            if isTransformed {
                headerSection
                    .padding(.top, headerTopPadding)
                    .padding(.bottom, 2)
            }

            if isTransformed {
                if showCarousel {
                    OnboardingFeatureCardCarouselView(
                        isActive: true,
                        initialAdvanceDelay: .milliseconds(680)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .opacity(carouselRevealed ? 1 : 0)
                    .animation(carouselFadeAnimation, value: carouselRevealed)
                } else {
                    Spacer(minLength: 0)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .layoutPriority(1)
                }
            } else {
                Spacer(minLength: 0)
            }

            if isTransformed {
                swipeToStartSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, footerBottomPadding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 14) {
            Color.clear
                .frame(width: heroSmallSize, height: heroSmallSize)

            Text("OPENCORE")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .monoTracking()
                .tracking(6)
                .foregroundStyle(palette.textPrimary)
                .opacity(isTransformed ? 1 : 0)
                .offset(x: isTransformed ? 0 : -14)
                .blur(radius: isTransformed || reduceMotion ? 0 : 4)
                .animation(headerTitleAnimation, value: isTransformed)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, headerHorizontalPadding)
    }

    private var swipeToStartSection: some View {
        OnboardingSwipeToStartView(isUnlocked: $swipeCompleted, onComplete: onComplete)
            .opacity(isTransformed ? 1 : 0)
            .offset(y: isTransformed ? 0 : 28)
            .blur(radius: isTransformed || reduceMotion ? 0 : 4)
            .animation(swipeSectionAnimation, value: isTransformed)
    }
}

// MARK: - Hero Cube Overlay (isolates heroTransition-driven layout)

private struct OnboardingHeroCubeOverlay: View, Animatable {
    var transition: CGFloat
    let appeared: Bool
    let morphPaused: Bool
    let containerSize: CGSize
    let inkColor: Color
    let largeSize: CGFloat
    let smallSize: CGFloat
    let headerTopPadding: CGFloat
    let headerHorizontalPadding: CGFloat
    let safeTop: CGFloat

    var animatableData: CGFloat {
        get { transition }
        set { transition = newValue }
    }

    var body: some View {
        let layout = OnboardingSinglePageView.heroCubeLayout(
            transition: transition,
            in: containerSize,
            largeSize: largeSize,
            smallSize: smallSize,
            headerTopPadding: headerTopPadding,
            headerHorizontalPadding: headerHorizontalPadding,
            safeTop: safeTop
        )

        OnboardingCubeView(
            appeared: appeared,
            inkColor: inkColor,
            morphPaused: morphPaused,
            rotationProgress: OnboardingSinglePageView.heroRotationProgress(from: transition)
        )
            .frame(width: layout.size, height: layout.size)
            .position(x: layout.center.x, y: layout.center.y)
    }
}
