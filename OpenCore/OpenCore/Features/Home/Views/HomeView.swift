import SwiftUI

/// Root home screen — welcome state with composer, matching the OpenZone home layout.
struct HomeView: View {
    let onThemeToggle: () -> Void

    @State private var draftMessage = ""
    @State private var speedMode = HomeVisualDefaults.speedMode
    @FocusState private var isComposerFocused: Bool

    @Environment(\.sharedPalette) private var palette

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

                welcomeContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var welcomeContent: some View {
        WelcomeScrollContainer(
            isComposerFocused: isComposerFocused,
            dismissKeyboard: dismissComposerKeyboard
        ) { viewportHeight in
            HomeWelcomeView(viewportHeight: viewportHeight)
        } composer: {
            HomeComposerView(
                draftMessage: $draftMessage,
                speedMode: $speedMode,
                selectedModelTitle: HomeVisualDefaults.selectedModelTitle,
                contextUsage: HomeVisualDefaults.contextUsage,
                availableSpeedModes: HomeVisualDefaults.availableSpeedModes,
                isComposerFocused: $isComposerFocused
            )
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismissComposerKeyboard()
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(palette.textPrimary)
            }
            .accessibilityLabel("Show sidebar")

            Spacer()

            SharedThemeToggleButton(onTap: onThemeToggle)

            Button {
                dismissComposerKeyboard()
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

    @State private var restingViewportHeight: CGFloat = 0

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                Color.clear
                    .frame(height: 1)
                    .id(HomeScrollAnchor.welcomeTop)

                content(restingViewportHeight)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: restingViewportHeight > 0 ? restingViewportHeight : nil)
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
            .onPreferenceChange(WelcomeViewportHeightKey.self) { newHeight in
                if !isComposerFocused {
                    restingViewportHeight = newHeight
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                composer()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
                withAnimation(.easeInOut(duration: duration)) {
                    scrollProxy.scrollTo(HomeScrollAnchor.welcomeBottom, anchor: .bottom)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notification in
                let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
                withAnimation(.easeInOut(duration: duration)) {
                    scrollProxy.scrollTo(HomeScrollAnchor.welcomeTop, anchor: .top)
                }
            }
        }
    }
}

private struct WelcomeViewportHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    HomeView(onThemeToggle: { })
        .environment(\.sharedPalette, SharedOpenZonePalette.resolve(.light))
}
