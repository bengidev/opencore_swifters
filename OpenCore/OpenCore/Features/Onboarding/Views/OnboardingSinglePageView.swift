import SwiftUI

/// Single-page onboarding — one persistent cube hero animates from center to the header slot,
/// then feature cards and the swipe CTA stagger in. Uses explicit frame interpolation because
/// `matchedGeometryEffect` does not reliably morph `UIViewRepresentable` content.
struct OnboardingSinglePageView: View {
    var onComplete: () async -> Bool = { true }

    @Environment(\.sharedPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var cubeAppeared = false
    /// 0 = large centered hero, 1 = docked header icon. Interpolated by the hero spring.
    @State private var heroMorph: CGFloat = 0
    @State private var isTransformed = false
    @State private var swipeCompleted = false
    @State private var transitionTask: Task<Void, Never>?

    private let heroLargeSize: CGFloat = 220
    private let heroSmallSize: CGFloat = 36
    private let headerTopPadding: CGFloat = 30
    private let headerHorizontalPadding: CGFloat = 24
    private let chatVerticalInset: CGFloat = 44
    private let footerBottomPadding: CGFloat = 6

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                if isTransformed {
                    headerSection
                        .padding(.top, headerTopPadding)
                        .padding(.bottom, 10)
                }

                if isTransformed {
                    OnboardingFeatureChatFeedView(isActive: isTransformed)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 20)
                        .padding(.vertical, chatVerticalInset)
                        .opacity(isTransformed ? 1 : 0)
                        .animation(
                            reduceMotion
                                ? .easeOut(duration: 0.2)
                                : .spring(response: 0.58, dampingFraction: 0.78).delay(0.22),
                            value: isTransformed
                        )
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

            GeometryReader { proxy in
                heroCube(
                    morph: heroMorph,
                    appeared: cubeAppeared,
                    containerSize: proxy.size,
                    safeTop: 0
                )
            }
        }
        .background {
            palette.surfaceBase
                .ignoresSafeArea()
        }
        .onAppear {
            cubeAppeared = true
            scheduleHeroTransformation()
        }
        .onDisappear {
            transitionTask?.cancel()
            transitionTask = nil
        }
    }

    // MARK: - Transformed Layout

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

    // MARK: - Orchestration

    private func scheduleHeroTransformation() {
        transitionTask?.cancel()
        transitionTask = Task {
            if !reduceMotion {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { return }
            }

            await MainActor.run {
                triggerHeroTransformation()
            }
        }
    }

    @ViewBuilder
    private func heroCube(
        morph: CGFloat,
        appeared: Bool,
        containerSize: CGSize,
        safeTop: CGFloat
    ) -> some View {
        let layout = Self.heroCubeLayout(
            morph: morph,
            in: containerSize,
            largeSize: heroLargeSize,
            smallSize: heroSmallSize,
            headerTopPadding: headerTopPadding,
            headerHorizontalPadding: headerHorizontalPadding,
            safeTop: safeTop
        )

        OnboardingCubeView(appeared: appeared)
            .frame(width: layout.size, height: layout.size)
            .position(x: layout.center.x, y: layout.center.y)
    }

    @MainActor
    private func triggerHeroTransformation() {
        let transformationSpring = Animation.spring(
            response: 0.75,
            dampingFraction: 0.82,
            blendDuration: 0.2
        )

        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.35)) {
                heroMorph = 1
                isTransformed = true
            }
        } else {
            withAnimation(transformationSpring) {
                heroMorph = 1
                isTransformed = true
            }
        }
    }
}

