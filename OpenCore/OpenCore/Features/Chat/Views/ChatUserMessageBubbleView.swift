import AVFoundation
import SwiftUI
import UIKit

struct ChatUserMessageBubbleView: View {
    let textMessage: ChatTextMessage

    @Environment(\.sharedPalette) private var palette
    @State private var voiceNotePlayback = ChatVoiceNotePlaybackController()

    private let cornerRadius: CGFloat = 20
    private let oppositeSpacerMinWidth: CGFloat = 60

    var body: some View {
        HStack {
            Spacer(minLength: oppositeSpacerMinWidth)

            VStack(alignment: .trailing, spacing: 8) {
                if !textMessage.attachments.isEmpty {
                    attachmentsContent
                }

                if !textMessage.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(textMessage.content)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(palette.controlStrongText)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(palette.controlStrong)
                        )
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .onDisappear {
            voiceNotePlayback.stop()
        }
    }

    @ViewBuilder
    private var attachmentsContent: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(textMessage.attachments) { attachment in
                switch attachment.kind {
                case .image:
                    ChatUserImageAttachmentBubbleView(attachment: attachment)
                case .video:
                    ChatUserVideoAttachmentBubbleView(attachment: attachment)
                case .audio:
                    ChatUserAudioAttachmentBubbleView(
                        attachment: attachment,
                        playback: voiceNotePlayback
                    )
                case .file:
                    ChatUserFileAttachmentBubbleView(attachment: attachment)
                }
            }
        }
    }
}

private struct ChatUserImageAttachmentBubbleView: View {
    let attachment: ChatMessageAttachment

    @State private var isPreviewPresented = false

    var body: some View {
        Button {
            isPreviewPresented = true
        } label: {
            ChatAttachmentThumbnailView(
                thumbnailJPEGData: attachment.thumbnailJPEGData,
                localPath: attachment.localPath,
                side: 148,
                cornerRadius: 16
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Image attachment \(attachment.filename)")
        .sheet(isPresented: $isPreviewPresented) {
            if let image = UIImage(contentsOfFile: attachment.localPath)
                ?? attachment.thumbnailJPEGData.flatMap({ UIImage(data: $0) }) {
                NavigationStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding()
                        .navigationTitle(attachment.filename)
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }
}

private struct ChatUserVideoAttachmentBubbleView: View {
    let attachment: ChatMessageAttachment

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "video.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.controlStrongText)

            Text(attachment.filename)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.controlStrongText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(palette.controlStrong)
        )
        .accessibilityLabel("Video attachment \(attachment.filename)")
    }
}

private struct ChatUserAudioAttachmentBubbleView: View {
    let attachment: ChatMessageAttachment
    let playback: ChatVoiceNotePlaybackController

    @Environment(\.sharedPalette) private var palette

    private var isPlaying: Bool {
        playback.isPlaying(attachmentID: attachment.id)
    }

    private var isPlaybackActive: Bool {
        playback.isActive(attachmentID: attachment.id)
    }

    private var waveformHeights: [Float] {
        SpeechRecordingDisplayLogic.waveformBarHeights(
            levels: attachment.waveformSamples,
            barCount: 16
        )
    }

    var body: some View {
        Button {
            playback.toggle(attachment: attachment)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.controlStrongText)

                ChatWaveformBarsView(
                    heights: waveformHeights,
                    progress: playback.playbackProgress(for: attachment),
                    showsPlaybackProgress: isPlaybackActive,
                    activeColor: palette.controlStrongText,
                    idleColor: palette.controlStrongText.opacity(0.35),
                    unplayedColor: palette.controlStrongText.opacity(0.22)
                )
                .frame(height: 24)

                Text(
                    SpeechRecordingDisplayLogic.formatElapsedDuration(
                        playback.displayedDuration(for: attachment)
                    )
                )
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.controlStrongText.opacity(0.85))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.linear(duration: 0.05), value: playback.displayedDuration(for: attachment))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(palette.controlStrong)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Pause voice note" : "Play voice note")
    }
}

private struct ChatUserFileAttachmentBubbleView: View {
    let attachment: ChatMessageAttachment

    @Environment(\.sharedPalette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.controlStrongText)

            Text(attachment.filename)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.controlStrongText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(palette.controlStrong)
        )
        .accessibilityLabel("File attachment \(attachment.filename)")
    }
}
