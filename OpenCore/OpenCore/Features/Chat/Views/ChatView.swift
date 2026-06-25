import SwiftUI

/// Active conversation screen — title and message thread only.
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
            }

            ChatThreadView(flow: chat)
                .contentShape(Rectangle())
                .onTapGesture(perform: dismissKeyboard)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ZStack {
        SharedOpenCorePalette.resolve(.light).surfaceBase.ignoresSafeArea()
        ChatView(chat: ChatFlowController(), dismissKeyboard: {})
    }
    .environment(\.sharedPalette, SharedOpenCorePalette.resolve(.light))
}
