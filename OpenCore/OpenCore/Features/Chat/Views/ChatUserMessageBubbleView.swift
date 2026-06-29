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

    @Environment(\.sharedPalette) private var palette
    @State private var isPreviewPresented = false

    var body: some View {
        Button {
            isPreviewPresented = true
        } label: {
            Group {
                if let thumbnailJPEGData = attachment.thumbnailJPEGData,
                   let image = UIImage(data: thumbnailJPEGData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if let image = UIImage(contentsOfFile: attachment.localPath) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(palette.surfaceSubtle)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(palette.textTertiary)
                        }
                }
            }
            .frame(width: 148, height: 148)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(palette.lineSoft.opacity(0.8), lineWidth: 1)
            }
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
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(palette.controlStrong)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Pause voice note" : "Play voice note")
    }

    private let cornerRadius: CGFloat = 20
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

private struct ChatWaveformBarsView: View {
    let heights: [Float]
    var progress: Double = 0
    var showsPlaybackProgress = false
    let activeColor: Color
    let idleColor: Color
    var unplayedColor: Color?

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(heights.enumerated()), id: \.offset) { index, height in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(barColor(for: index, height: height))
                    .frame(width: 3, height: max(4, CGFloat(height) * 24))
                    .animation(.easeOut(duration: 0.08), value: progress)
            }
        }
    }

    private func barColor(for index: Int, height: Float) -> Color {
        let baseColor = height > 0.12 ? activeColor : idleColor
        guard showsPlaybackProgress else { return baseColor }

        let played = ChatVoiceNotePlaybackDisplayLogic.isBarPlayed(
            barIndex: index,
            barCount: heights.count,
            progress: progress
        )
        if played {
            return baseColor
        }
        return unplayedColor ?? idleColor
    }
}
