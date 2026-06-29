import SwiftUI

/// Top processing bar shown while media text extraction runs.
struct VisionProcessingIndicatorView: View {
    let statusMessage: String
    let onCancel: () -> Void

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .tint(palette.accentPrimary)
                .accessibilityHidden(true)

            Text(statusMessage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.textSecondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
                    .frame(width: 28, height: 28)
                    .background {
                        Circle()
                            .fill(palette.surfaceSubtle.opacity(palette.isDark ? 0.55 : 0.85))
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel media import")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.surfaceSubtle.opacity(palette.isDark ? 0.35 : 0.55))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statusMessage)
    }
}
