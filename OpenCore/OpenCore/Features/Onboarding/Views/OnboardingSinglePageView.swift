import SwiftUI

/// Single-page onboarding — cube hero, wordmark, editorial copy, swipe CTA.
///
/// Composition (top → bottom): wireframe cube hero (~21% height) that
/// materializes from particles, "OPENCORE" wordmark, italic value-prop body,
/// and a black pill CTA with a white circle + arrow that commits onboarding
/// via swipe or tap. Follows the system theme through the shared palette.
struct OnboardingSinglePageView: View {
    @Environment(\.sharedPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appeared = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                // Canvas — pure background, no grid/hatch/atmosphere (concept)
                palette.surfaceBase
                    .ignoresSafeArea()

                // The concept is a single centered hero, not a paged onboarding shell.
                // Construction reveal is the entrance — no separate opacity fade.
                OnboardingCubeView(appeared: appeared)
                    .frame(
                        width: min(size.width * 0.36, 150),
                        height: min(size.height * 0.21, 180)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .sensoryFeedback(.selection, trigger: appeared)
        }
        .task {
            await runEntrance()
        }
    }

    // MARK: - Entrance

    @MainActor
    private func runEntrance() async {
        appeared = false
        guard !reduceMotion else {
            appeared = true
            return
        }
        try? await Task.sleep(nanoseconds: 70_000_000)
        appeared = true
    }

}
