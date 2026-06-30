import SwiftUI

@MainActor
enum HomeContextUsagePopoverMotion {
    static let animation = Animation.spring(response: 0.34, dampingFraction: 0.86)
    private static let reduceMotionAnimation = Animation.easeInOut(duration: 0.16)

    static let transition = AnyTransition.asymmetric(
        insertion: .opacity
            .combined(with: .scale(scale: 0.92, anchor: .bottomTrailing))
            .combined(with: .offset(y: 10)),
        removal: .opacity
            .combined(with: .scale(scale: 0.97, anchor: .bottomTrailing))
            .combined(with: .offset(y: 6))
    )

    static func presentationAnimation(reduceMotion: Bool) -> Animation {
        reduceMotion ? reduceMotionAnimation : animation
    }

    static func popoverTransition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : transition
    }
}

/// Tap-outside scrim for the context usage popover. Intended for the scroll area only
/// so the composer stays interactive while the popover is open.
struct HomeContextUsageDismissScrim: View {
    let reduceMotion: Bool
    let onDismiss: () -> Void

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        palette.scrimOverlay(opacity: reduceMotion ? 0.001 : 0.06)
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
    }
}
