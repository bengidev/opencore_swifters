import SwiftUI

/// Completed assistant answer text with native markdown styling.
struct ChatAssistantMarkdownTextView: View {
    let text: String

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        Text(ChatAssistantMarkdownRenderer.attributedString(from: text, palette: palette))
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }
}
