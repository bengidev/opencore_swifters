import SwiftUI

/// Active conversation screen — title, error banner, and message thread.
/// Composer is inset on the thread scroll view so its viewport tracks the keyboard.
struct ChatView<Composer: View>: View {
    @Bindable var chat: ChatFlowController
    let dismissKeyboard: () -> Void
    var isComposerFocused = false
    @ViewBuilder let composer: () -> Composer

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            if let conversation = chat.state.conversation {
                Text(conversation.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    .accessibilityAddTraits(.isHeader)
            }

            ChatThreadView(flow: chat, isComposerFocused: isComposerFocused) {
                VStack(spacing: 0) {
                    ChatErrorBannerView(flow: chat)
                        .animation(.easeInOut(duration: 0.2), value: chat.state.streamingStatus)
                    composer()
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: dismissKeyboard)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ZStack {
        SharedOpenCorePalette.resolve(.light).surfaceBase.ignoresSafeArea()
        ChatView(chat: ChatFlowController(), dismissKeyboard: {}, composer: { EmptyView() })
    }
    .environment(\.sharedPalette, SharedOpenCorePalette.resolve(.light))
}
