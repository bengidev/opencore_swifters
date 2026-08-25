import SwiftUI

/// Single-page onboarding — one persistent cube hero animates from center to the header slot,
/// then feature cards auto-swipe in a loop and the swipe CTA staggers in.
struct OnboardingSinglePageView: View {
    var onComplete: () async -> Bool = { true }

    @Environment(\.sharedPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var cubeAppeared = false
    /// 0 = large centered hero, 1 = docked header icon. Interpolated by the hero spring.
    @State private var heroMorph: CGFloat = 0
    /// 0 = idle cube morph, 1 = locked to the header isometric wireframe pose.
    @State private var heroRotation: CGFloat = 0
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
    private let heroRotationSettleDelay: Duration = .milliseconds(500)
    private let heroShrinkPauseDelay: Duration = .milliseconds(320)

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
                    morph: heroMorph,
                    rotationProgress: heroRotation,
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

    static func heroCubeLayout(
        morph: CGFloat,
        in size: CGSize,
        largeSize: CGFloat,
        smallSize: CGFloat,
        headerTopPadding: CGFloat,
        headerHorizontalPadding: CGFloat,
        safeTop: CGFloat
    ) -> HeroCubeLayout {
        let cubeSize = largeSize + (smallSize - largeSize) * morph

        let largeCenter = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        let smallCenter = CGPoint(
            x: headerHorizontalPadding + smallSize * 0.5,
            y: safeTop + headerTopPadding + smallSize * 0.5
        )

        return HeroCubeLayout(
            size: cubeSize,
            center: CGPoint(
                x: largeCenter.x + (smallCenter.x - largeCenter.x) * morph,
                y: largeCenter.y + (smallCenter.y - largeCenter.y) * morph
            )
        )
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
        let rotationSpring = Animation.spring(response: 0.52, dampingFraction: 0.84)
        let transformationSpring = Animation.spring(
            response: 0.75,
            dampingFraction: 0.82,
            blendDuration: 0.2
        )

        if reduceMotion {
            heroRotation = 1
            withAnimation(.easeInOut(duration: 0.35)) {
                heroMorph = 1
                isTransformed = true
            }
            scheduleCarouselAppearance()
            return
        }

        withAnimation(rotationSpring) {
            heroRotation = 1
        }

        transitionTask?.cancel()
        transitionTask = Task {
            try? await Task.sleep(for: heroRotationSettleDelay)
            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: heroShrinkPauseDelay)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(transformationSpring) {
                    heroMorph = 1
                    isTransformed = true
                }
                scheduleCarouselAppearance()
            }
        }
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

// MARK: - Hero Cube Overlay (isolates heroMorph-driven layout)

private struct OnboardingHeroCubeOverlay: View, Animatable {
    var morph: CGFloat
    var rotationProgress: CGFloat
    let appeared: Bool
    let morphPaused: Bool
    let containerSize: CGSize
    let inkColor: Color
    let largeSize: CGFloat
    let smallSize: CGFloat
    let headerTopPadding: CGFloat
    let headerHorizontalPadding: CGFloat
    let safeTop: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(morph, rotationProgress) }
        set {
            morph = newValue.first
            rotationProgress = newValue.second
        }
    }

    var body: some View {
        let layout = OnboardingSinglePageView.heroCubeLayout(
            morph: morph,
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
            rotationProgress: rotationProgress
        )
            .frame(width: layout.size, height: layout.size)
            .position(x: layout.center.x, y: layout.center.y)
    }
}
