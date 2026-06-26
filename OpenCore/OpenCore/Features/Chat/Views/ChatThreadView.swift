import SwiftUI

private enum ChatThreadLayout {
    static let keyboardScrollDelayNanoseconds: UInt64 = 180_000_000
}

/// Scrollable message list for an active chat conversation. Auto-scrolls as
/// messages stream in and shows a typing indicator before the first assistant
/// token arrives.
struct ChatThreadView<BottomChrome: View>: View {
    @Bindable var flow: ChatFlowController
    var isComposerFocused = false
    @ViewBuilder var bottomChrome: () -> BottomChrome

    @Environment(\.sharedPalette) private var palette
    @State private var scrollTask: Task<Void, Never>?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(flow.state.messages) { message in
                        ChatMessageRowView(
                            message: message,
                            isLastAssistantMessage: isLastAssistantMessage(message),
                            streamingStatus: flow.state.streamingStatus,
                            streamErrorMessage: flow.state.streamErrorMessage
                        )
                        .equatable()
                        .id(message.id)
                    }

                    if showLoadingIndicator {
                        ChatLoadingIndicatorView()
                            .id("loading-indicator")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomChrome()
            }
            .background(palette.surfaceBase)
            .onChange(of: flow.state.messages.count) { _, _ in
                scheduleScrollToLast(proxy: proxy, animate: true)
            }
            .onChange(of: flow.state.streamingRevision) { _, _ in
                scheduleScrollToLast(proxy: proxy, animate: false)
            }
            .onChange(of: flow.state.streamingStatus) { _, _ in
                scheduleScrollToLast(proxy: proxy, animate: true)
            }
            .onChange(of: showLoadingIndicator) { _, showing in
                if showing {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("loading-indicator", anchor: .bottom)
                    }
                }
            }
            .onChange(of: isComposerFocused) { _, isFocused in
                scheduleScrollToLast(
                    proxy: proxy,
                    animate: true,
                    delayNanoseconds: isFocused
                        ? ChatThreadLayout.keyboardScrollDelayNanoseconds
                        : 0
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { _ in
                guard isComposerFocused else { return }
                scheduleScrollToLast(
                    proxy: proxy,
                    animate: true,
                    delayNanoseconds: ChatThreadLayout.keyboardScrollDelayNanoseconds
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var showLoadingIndicator: Bool {
        guard flow.state.streamingStatus == .running else { return false }
        return flow.state.messages.last?.role == .user
    }

    private func isLastAssistantMessage(_ message: ChatMessage) -> Bool {
        guard message.role == .assistant,
              let lastAssistantIndex = flow.state.messages.lastIndex(where: { $0.role == .assistant })
        else { return false }
        return flow.state.messages[lastAssistantIndex].id == message.id
    }

    private func scheduleScrollToLast(
        proxy: ScrollViewProxy,
        animate: Bool,
        delayNanoseconds: UInt64? = nil
    ) {
        scrollTask?.cancel()
        scrollTask = Task { @MainActor in
            let delay = delayNanoseconds ?? scrollCoalesceDelayNanoseconds()
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            } else {
                await Task.yield()
            }
            guard !Task.isCancelled else { return }
            scrollToLast(proxy: proxy, animate: animate)
            scrollTask = nil
        }
    }

    private func scrollCoalesceDelayNanoseconds() -> UInt64 {
        let byteCount = flow.state.currentPartialText.utf8.count
        if byteCount >= 32_000 { return 200_000_000 }
        if byteCount >= 8_000 { return 120_000_000 }
        return 0
    }

    private func scrollToLast(proxy: ScrollViewProxy, animate: Bool) {
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
