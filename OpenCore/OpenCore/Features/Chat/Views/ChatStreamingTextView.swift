import SwiftUI
import UIKit

/// UIKit-backed growing text for live assistant output. Appends deltas into
/// `textStorage` instead of rebuilding SwiftUI `Text` layout on every flush.
struct ChatStreamingTextView: UIViewRepresentable {
    let text: String
    var font: UIFont = .systemFont(ofSize: 16, weight: .regular)
    var textColor: UIColor = .label
    var markdownPalette: SharedOpenCorePalette?
    var isSelectable = true
    var showsCursor = false
    var cursorColor: UIColor = .label
    var cursorOpacity: CGFloat = 1

    private static let cursorGlyph = "▍"

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
        context.coordinator.apply(
            text: text,
            to: uiView,
            font: font,
            textColor: textColor,
            markdownPalette: markdownPalette,
            showsCursor: showsCursor,
            cursorColor: cursorColor,
            cursorOpacity: cursorOpacity
        )
    }

    @MainActor
    final class Coordinator {
        private var appliedText = ""
        private var appliedShowsCursor = false
        private var appliedCursorOpacity: CGFloat = 1
        private var pendingText = ""
        private var pendingShowsCursor = false
        private var pendingCursorColor: UIColor = .label
        private var pendingCursorOpacity: CGFloat = 1
        private var updateTask: Task<Void, Never>?
        private var lastLayoutInvalidation = Date.distantPast

        func apply(
            text: String,
            to textView: ChatStreamingSizingTextView,
            font: UIFont,
            textColor: UIColor,
            markdownPalette: SharedOpenCorePalette?,
            showsCursor: Bool,
            cursorColor: UIColor,
            cursorOpacity: CGFloat
        ) {
            pendingText = text
            pendingShowsCursor = showsCursor
            pendingCursorColor = cursorColor
            pendingCursorOpacity = cursorOpacity
            pendingMarkdownPalette = markdownPalette
            guard updateTask == nil else { return }
            updateTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 33_000_000)
                guard !Task.isCancelled else { return }
                flushPending(to: textView, font: font, textColor: textColor)
                updateTask = nil
            }
        }

        private var pendingMarkdownPalette: SharedOpenCorePalette?

        private func flushPending(
            to textView: ChatStreamingSizingTextView,
            font: UIFont,
            textColor: UIColor
        ) {
            let text = pendingText
            let showsCursor = pendingShowsCursor
            let cursorOpacity = pendingCursorOpacity
            let cursorAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: pendingCursorColor.withAlphaComponent(cursorOpacity),
            ]
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor,
            ]

            if text == appliedText,
               showsCursor,
               appliedShowsCursor,
               cursorOpacity != appliedCursorOpacity,
               textView.textStorage.length > 0 {
                let cursorRange = NSRange(location: textView.textStorage.length - 1, length: 1)
                textView.textStorage.addAttributes(cursorAttributes, range: cursorRange)
                appliedCursorOpacity = cursorOpacity
                return
            }

            guard text != appliedText
                || showsCursor != appliedShowsCursor
                || cursorOpacity != appliedCursorOpacity else { return }

            if let markdownPalette = pendingMarkdownPalette {
                let rendered = NSMutableAttributedString(
                    attributedString: ChatAssistantMarkdownRenderer.nsAttributedString(
                        from: text,
                        palette: markdownPalette,
                        cacheResult: false
                    )
                )
                if showsCursor {
                    rendered.append(NSAttributedString(string: ChatStreamingTextView.cursorGlyph, attributes: cursorAttributes))
                }
                textView.attributedText = rendered
            } else if text.count > appliedText.count,
               text.hasPrefix(appliedText),
               showsCursor == appliedShowsCursor {
                let storage = textView.textStorage
                storage.beginEditing()
                if appliedShowsCursor, storage.length > 0 {
                    storage.deleteCharacters(in: NSRange(location: storage.length - 1, length: 1))
                }
                let delta = String(text.dropFirst(appliedText.count))
                storage.append(NSAttributedString(string: delta, attributes: attributes))
                if showsCursor {
                    storage.append(NSAttributedString(string: ChatStreamingTextView.cursorGlyph, attributes: cursorAttributes))
                }
                storage.endEditing()
            } else {
                let rendered = NSMutableAttributedString(string: text, attributes: attributes)
                if showsCursor {
                    rendered.append(NSAttributedString(string: ChatStreamingTextView.cursorGlyph, attributes: cursorAttributes))
                }
                textView.attributedText = rendered
            }

            appliedText = text
            appliedShowsCursor = showsCursor
            appliedCursorOpacity = cursorOpacity
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
