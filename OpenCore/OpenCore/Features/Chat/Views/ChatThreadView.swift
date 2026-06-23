import SwiftUI

/// Scrollable message list for an active chat conversation. Auto-scrolls as
/// messages stream in and shows a typing indicator before the first assistant
/// token arrives.
struct ChatThreadView: View {
    @Bindable var flow: ChatFlowController

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(flow.state.messages) { message in
                    ChatMessageRowView(
                        message: message,
                        isLastAssistantMessage: isLastAssistantMessage(message),
                        streamingStatus: flow.state.streamingStatus,
                        streamErrorMessage: flow.state.streamErrorMessage
                    )
                    .id(message.id)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(palette.surfaceBase)
                    .listRowSeparator(.hidden)
                }

                if showLoadingIndicator {
                    ChatLoadingIndicatorView()
                        .id("loading-indicator")
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(palette.surfaceBase)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, 0)
            .background(palette.surfaceBase)
            .onChange(of: flow.state.messages.count) { _, _ in
                scrollToLast(proxy: proxy, animate: true)
            }
            .onChange(of: flow.state.currentPartialText.count) { _, _ in
                scrollToLast(proxy: proxy, animate: false)
            }
            .onChange(of: flow.state.currentPartialThinking.count) { _, _ in
                scrollToLast(proxy: proxy, animate: false)
            }
            .onChange(of: flow.state.streamingStatus) { _, _ in
                scrollToLast(proxy: proxy, animate: true)
            }
            .onChange(of: showLoadingIndicator) { _, showing in
                if showing {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("loading-indicator", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var showLoadingIndicator: Bool {
        guard flow.state.streamingStatus == .running else { return false }
        // Show indicator only when no assistant response yet — the last message
        // must be a user message (covers both fresh send and retry).
        return flow.state.messages.last?.role == .user
    }

    private func isLastAssistantMessage(_ message: ChatMessage) -> Bool {
        guard message.role == .assistant,
              let lastAssistantIndex = flow.state.messages.lastIndex(where: { $0.role == .assistant })
        else { return false }
        return flow.state.messages[lastAssistantIndex].id == message.id
    }

    private func scrollToLast(proxy: ScrollViewProxy, animate: Bool) {
        // The reasoning row is now an item-scoped message in `flow.state.messages`
        // (see ChatFeature.streamingThinkingID), so the last message id is
        // always the correct scroll anchor — no separate live-stream row.
        guard let scrollTarget = flow.state.messages.last?.id else { return }

        if animate {
            withAnimation(.easeOut(duration: 0.15)) {
                proxy.scrollTo(scrollTarget, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(scrollTarget, anchor: .bottom)
        }
    }
}
