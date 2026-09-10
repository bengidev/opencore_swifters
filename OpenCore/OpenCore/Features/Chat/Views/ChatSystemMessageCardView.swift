import SwiftUI

/// Inline system notice bubble with distinct card chrome.
struct ChatSystemMessageCardView: View {
    let content: String

    var body: some View {
        ChatMessageCardChrome {
            VStack(alignment: .leading, spacing: 8) {
                ChatMessageCardHeader(icon: "info.circle", title: "System")

                ChatRichContentView(text: content, style: .system)
            }
        }
    }
}
