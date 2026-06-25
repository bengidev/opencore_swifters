import SwiftUI
import UIKit

/// UIKit-backed growing text for live assistant output. Appends deltas into
/// `textStorage` instead of rebuilding SwiftUI `Text` layout on every flush.
struct ChatStreamingTextView: UIViewRepresentable {
    let text: String
    let font: UIFont
    let textColor: UIColor
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
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .vertical)
        return textView
    }

    func updateUIView(_ uiView: ChatStreamingSizingTextView, context: Context) {
        uiView.isSelectable = isSelectable
        context.coordinator.apply(
            text: text,
            to: uiView,
            font: font,
            textColor: textColor
        )
    }

    @MainActor
    final class Coordinator {
        private var appliedText = ""
        private var pendingText = ""
        private var updateTask: Task<Void, Never>?
        private var lastLayoutInvalidation = Date.distantPast

        func apply(text: String, to textView: ChatStreamingSizingTextView, font: UIFont, textColor: UIColor) {
            pendingText = text
            guard updateTask == nil else { return }
            updateTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 33_000_000)
                guard !Task.isCancelled else { return }
                flushPending(to: textView, font: font, textColor: textColor)
                updateTask = nil
            }
        }

        private func flushPending(
            to textView: ChatStreamingSizingTextView,
            font: UIFont,
            textColor: UIColor
        ) {
            let text = pendingText
            guard text != appliedText else { return }

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor,
            ]

            if text.count > appliedText.count, text.hasPrefix(appliedText) {
                let delta = String(text.dropFirst(appliedText.count))
                let storage = textView.textStorage
                storage.beginEditing()
                storage.append(NSAttributedString(string: delta, attributes: attributes))
                storage.endEditing()
            } else {
                textView.attributedText = NSAttributedString(string: text, attributes: attributes)
            }

            appliedText = text
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

/// Non-scrolling `UITextView` that reports height for SwiftUI layout.
@MainActor
final class ChatStreamingSizingTextView: UITextView {
    private var measuredWidth: CGFloat = 0
    private var measuredHeight: CGFloat?
    private var measuredLength = 0

    override var intrinsicContentSize: CGSize {
        let width = bounds.width > 1 ? bounds.width : UIScreen.main.bounds.width - 56
        if let measuredHeight, width == measuredWidth, textStorage.length == measuredLength {
            return CGSize(width: UIView.noIntrinsicMetric, height: measuredHeight)
        }

        let fitted = sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        measuredWidth = width
        measuredHeight = fitted.height
        measuredLength = textStorage.length
        return CGSize(width: UIView.noIntrinsicMetric, height: fitted.height)
    }

    func invalidateMeasuredHeight() {
        measuredHeight = nil
        invalidateIntrinsicContentSize()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.width > 1, bounds.width != measuredWidth {
            invalidateMeasuredHeight()
        }
    }
}
