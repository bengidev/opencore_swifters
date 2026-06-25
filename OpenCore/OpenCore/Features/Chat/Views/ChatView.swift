import SwiftUI

/// Active conversation screen — title, error banner, and message thread.
/// Composer stays in `HomeView`.
struct ChatView: View {
    @Bindable var chat: ChatFlowController
    let dismissKeyboard: () -> Void

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

            ChatThreadView(flow: chat)
                .contentShape(Rectangle())
                .onTapGesture(perform: dismissKeyboard)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ChatErrorBannerView(flow: chat)
                .animation(.easeInOut(duration: 0.2), value: chat.state.streamingStatus)
        }
    }
}

#Preview {
    ZStack {
        SharedOpenCorePalette.resolve(.light).surfaceBase.ignoresSafeArea()
        ChatView(chat: ChatFlowController(), dismissKeyboard: {})
    }
    .environment(\.sharedPalette, SharedOpenCorePalette.resolve(.light))
}
