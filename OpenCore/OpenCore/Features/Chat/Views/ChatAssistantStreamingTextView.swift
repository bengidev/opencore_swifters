import SwiftUI
import UIKit

/// Markdown-aware streaming assistant text — full attributed rebuild per flush.
struct ChatAssistantStreamingTextView: UIViewRepresentable {
    let text: String
    let palette: SharedOpenCorePalette
    var isSelectable = true

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ChatStreamingSizingTextView {
        let textView = ChatStreamingSizingTextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.clipsToBounds = true
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .vertical)
        return textView
    }

    func updateUIView(_ uiView: ChatStreamingSizingTextView, context: Context) {
        uiView.isSelectable = isSelectable
        context.coordinator.apply(text: text, palette: palette, to: uiView)
    }

    @MainActor
    final class Coordinator {
        private var appliedText = ""
        private var appliedIsDark: Bool?
        private var pendingText = ""
        private var pendingPalette: SharedOpenCorePalette?
        private var updateTask: Task<Void, Never>?
        private var lastLayoutInvalidation = Date.distantPast

        func apply(text: String, palette: SharedOpenCorePalette, to textView: ChatStreamingSizingTextView) {
            pendingText = text
            pendingPalette = palette
            guard updateTask == nil else { return }
            updateTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 33_000_000)
                guard !Task.isCancelled else { return }
                flushPending(to: textView)
                updateTask = nil
            }
        }

        private func flushPending(to textView: ChatStreamingSizingTextView) {
            guard let palette = pendingPalette else { return }
            let text = pendingText
            let isDark = palette.isDark

            guard text != appliedText || isDark != appliedIsDark else { return }

            textView.attributedText = ChatAssistantMarkdownRenderer.nsAttributedString(
                from: text,
                palette: palette
            )

            appliedText = text
            appliedIsDark = isDark
            invalidateLayoutIfNeeded(for: textView)
        }

        private func invalidateLayoutIfNeeded(for textView: ChatStreamingSizingTextView) {
            let now = Date()
            let byteCount = appliedText.utf8.count
            let minInterval: TimeInterval = byteCount >= 32_000 ? 0.25 : (byteCount >= 8_000 ? 0.15 : 0.05)
            guard now.timeIntervalSince(lastLayoutInvalidation) >= minInterval else { return }
            lastLayoutInvalidation = now
            textView.invalidateMeasuredHeight()
        }
    }
}
