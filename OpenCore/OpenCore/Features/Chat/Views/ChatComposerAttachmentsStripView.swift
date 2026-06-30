import SwiftUI
import UIKit

/// Horizontal strip of pending composer attachments.
struct ChatComposerAttachmentsStripView: View {
    let attachments: [ChatMessageAttachment]
    let onRemove: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(attachments) { attachment in
                    ChatComposerAttachmentIndicatorView(attachment: attachment, onRemove: onRemove)
                }
            }
            .padding(.trailing, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ChatComposerAttachmentIndicatorView: View {
    let attachment: ChatMessageAttachment
    let onRemove: (UUID) -> Void

    var body: some View {
        switch attachment.kind {
        case .image:
            ChatImageAttachmentIndicatorView(attachment: attachment, onRemove: onRemove)
        case .video:
            ChatVideoAttachmentIndicatorView(attachment: attachment, onRemove: onRemove)
        case .audio:
            ChatAudioAttachmentIndicatorView(attachment: attachment, onRemove: onRemove)
        case .file:
            ChatFileAttachmentPillView(attachment: attachment, onRemove: onRemove)
        }
    }
}

private struct ChatImageAttachmentIndicatorView: View {
    let attachment: ChatMessageAttachment
    let onRemove: (UUID) -> Void

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ChatAttachmentThumbnailView(
                thumbnailJPEGData: attachment.thumbnailJPEGData,
                localPath: attachment.localPath
            )
            removeButton
        }
        .accessibilityLabel("Attached image \(attachment.filename)")
    }

    private var removeButton: some View {
        Button {
            onRemove(attachment.id)
        } label: {
            ZStack {
                Circle()
                    .fill(palette.controlStrong.opacity(0.82))
                    .frame(width: 18, height: 18)
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(palette.controlStrongText)
            }
        }
        .buttonStyle(.plain)
        .padding(5)
        .accessibilityLabel("Remove \(attachment.filename)")
    }
}

private struct ChatVideoAttachmentIndicatorView: View {
    let attachment: ChatMessageAttachment
    let onRemove: (UUID) -> Void

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "video.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.accentPrimary)

            Text(attachment.filename)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)

            Button {
                onRemove(attachment.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(palette.textTertiary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(attachment.filename)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.surfaceSubtle.opacity(palette.isDark ? 0.55 : 0.85))
        }
        .accessibilityLabel("Attached video \(attachment.filename)")
    }
}

private struct ChatAudioAttachmentIndicatorView: View {
    let attachment: ChatMessageAttachment
    let onRemove: (UUID) -> Void

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.accentPrimary)

            ChatWaveformBarsView(
                heights: SpeechRecordingDisplayLogic.waveformBarHeights(
                    levels: attachment.waveformSamples,
                    barCount: 12
                ),
                activeColor: palette.accentPrimary,
                idleColor: palette.textTertiary.opacity(0.45)
            )
            .frame(width: 72, height: 22)

            Text(SpeechRecordingDisplayLogic.formatElapsedDuration(attachment.audioDuration))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.textSecondary)

            Button {
                onRemove(attachment.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(palette.textTertiary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove voice note")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.surfaceSubtle.opacity(palette.isDark ? 0.55 : 0.85))
        }
        .accessibilityLabel("Attached voice note")
    }
}

private struct ChatFileAttachmentPillView: View {
    let attachment: ChatMessageAttachment
    let onRemove: (UUID) -> Void

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.accentPrimary)

            Text(attachment.filename)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)

            Button {
                onRemove(attachment.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(palette.textTertiary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(attachment.filename)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.surfaceSubtle.opacity(palette.isDark ? 0.55 : 0.85))
        }
        .accessibilityLabel("Attached file \(attachment.filename)")
    }
}
