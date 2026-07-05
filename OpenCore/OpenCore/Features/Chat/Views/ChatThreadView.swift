import SwiftUI

private enum ChatThreadLayout {
    static let keyboardScrollDelayNanoseconds: UInt64 = 180_000_000
    /// One layout pass after bulk history restore before scrolling to the tail.
    static let historyRestoreScrollDelayNanoseconds: UInt64 = 50_000_000
}

/// Scrollable message list for an active chat conversation. Auto-scrolls as
/// messages stream in; streaming status appears in a capsule above the composer.
struct ChatThreadView<BottomChrome: View>: View {
    @Bindable var flow: ChatFlowController
    var isComposerFocused = false
    var showsContextUsageDismissScrim = false
    var onDismissContextUsage: (() -> Void)?
    @ViewBuilder var bottomChrome: () -> BottomChrome

    @Environment(\.sharedPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                            streamErrorMessage: flow.state.streamErrorMessage,
                            collapseThinkingForDownstreamStream: shouldCollapseThinking(for: message)
                        )
                        .equatable()
                        .id(message.id)
                    }
                }
            }
            .defaultScrollAnchor(.bottom)
            .overlay {
                if showsContextUsageDismissScrim, let onDismissContextUsage {
                    HomeContextUsageDismissScrim(
                        reduceMotion: reduceMotion,
                        onDismiss: onDismissContextUsage
                    )
                    .transition(.opacity)
                }
            }
            .animation(
                HomeContextUsagePopoverMotion.presentationAnimation(reduceMotion: reduceMotion),
                value: showsContextUsageDismissScrim
            )
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomChrome()
            }
            .background(palette.surfaceBase)
            .onChange(of: flow.state.messages.count) { oldCount, newCount in
                let isBulkRestore = oldCount == 0 && newCount > 0
                scheduleScrollToLast(
                    proxy: proxy,
                    animate: !isBulkRestore,
                    delayNanoseconds: isBulkRestore
                        ? ChatThreadLayout.historyRestoreScrollDelayNanoseconds
                        : nil
                )
            }
            .onChange(of: flow.state.streamingRevision) { _, _ in
                scheduleScrollToLast(proxy: proxy, animate: false)
            }
            .onChange(of: flow.state.streamingStatus) { _, _ in
                scheduleScrollToLast(proxy: proxy, animate: true)
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
            .onReceive(NotificationCenter.default.publisher(for: .chatThreadRequestScrollToBottom)) { _ in
                scheduleScrollToLast(
                    proxy: proxy,
                    animate: true,
                    delayNanoseconds: ChatThreadLayout.historyRestoreScrollDelayNanoseconds
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func isLastAssistantMessage(_ message: ChatMessage) -> Bool {
        guard message.role == .assistant,
              let lastAssistantIndex = flow.state.messages.lastIndex(where: { $0.role == .assistant })
        else { return false }
        return flow.state.messages[lastAssistantIndex].id == message.id
    }

    private func shouldCollapseThinking(for message: ChatMessage) -> Bool {
        guard case .thinking = message else { return false }

        if flow.state.streamingAnswerID != nil || flow.state.streamingOutputStreamID != nil {
            return true
        }

        guard let index = flow.state.messages.firstIndex(where: { $0.id == message.id }) else {
            return false
        }

        return flow.state.messages[(index + 1)...].contains { downstream in
            switch downstream {
            case let .text(textMessage):
                textMessage.role == .assistant
            case .outputStream:
                true
            default:
                false
            }
        }
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
