import SwiftUI

/// Main onboarding view — responsive layout with geometry-based sizing.
struct OnboardingView: View {
    @Bindable var flow: OnboardingFlowController
    let onThemeToggle: () -> Void

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let compactHeight = size.height < 760
            let horizontalPadding = min(max(size.width * 0.055, 20), 36)
            let baseVisualHeight = max(
                compactHeight ? 270 : 326,
                min(size.height * (compactHeight ? 0.39 : 0.43), 390)
            )
            let visualHeight = flow.state.currentPageData.type == .reasoningControl
                ? baseVisualHeight + (compactHeight ? 48 : 32)
                : baseVisualHeight

            ZStack {
                palette.surfaceBase
                    .ignoresSafeArea()

                SharedPixelGridBackground(
                    spacing: compactHeight ? 18 : 22,
                    dotSize: 1.0,
                    opacity: palette.isDark ? 0.06 : 0.04
                )
                .ignoresSafeArea()

                SharedDiagonalHatchPattern(
                    spacing: 10,
                    opacity: palette.isDark ? 0.10 : 0.04
                )
                .ignoresSafeArea()

                VStack(spacing: compactHeight ? 12 : 18) {
                    OnboardingTopBarView(flow: flow, onThemeToggle: onThemeToggle)

                    OnboardingFeaturePageView(
                        page: flow.state.currentPageData,
                        visualHeight: visualHeight,
                        flow: flow
                    )
                    .id(flow.state.currentPageData.id)
                    .transition(.opacity)

                    OnboardingBottomNavigationView(flow: flow)
                }
                .frame(maxWidth: 680)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, compactHeight ? 8 : 12)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom + 10, 18))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .sensoryFeedback(.selection, trigger: flow.state.currentPage)
        }
    }
}
