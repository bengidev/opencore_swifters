import SwiftUI

/// Inline command execution row with litter-style shell header and live output viewport.
struct ChatOutputStreamCardView: View {
    let message: ChatOutputStreamMessage

    @Environment(\.sharedPalette) private var palette
    @State private var isExpanded: Bool

    init(message: ChatOutputStreamMessage) {
        self.message = message
        let isRunning = message.detail.status == .running && !message.isComplete
        _isExpanded = State(
            initialValue: isRunning || message.detail.status == .failed
        )
    }

    private var isRunning: Bool {
        message.detail.status == .running && !message.isComplete
    }

    private var display: ChatOutputStreamHumanizer.Info {
        ChatOutputStreamHumanizer.humanize(message.command, isRunning: isRunning)
    }

    private var displayedCommand: String {
        let trimmed = message.command.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "command" : trimmed
    }

    private var collapsedCommand: String {
        let collapsed = displayedCommand
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed.isEmpty ? "command" : collapsed
    }

    private var durationText: String? {
        guard let durationMs = message.detail.durationMs else { return nil }
        return formattedDuration(durationMs)
    }

    var body: some View {
        ChatMessageCardChrome {
            VStack(alignment: .leading, spacing: isExpanded ? 8 : 0) {
                shellHeader

                if isExpanded {
                    ChatOutputStreamViewport(
                        output: message.detail.outputTail,
                        status: message.detail.status,
                        durationText: durationText
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: isExpanded)
        .onChange(of: isRunning) { _, running in
            if running || message.detail.status == .failed {
                withAnimation(.easeOut(duration: 0.2)) {
                    isExpanded = true
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var shellHeader: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("$")
                    .font(SharedOpenCoreTypography.monoSM.weight(.semibold))
                    .foregroundStyle(palette.warning)

                Group {
                    if isExpanded {
                        Text(displayedCommand)
                    } else {
                        Text("\(display.verb) \(display.target)")
                    }
                }
                .font(SharedOpenCoreTypography.monoSM)
                .foregroundStyle(palette.textPrimary)
                .textSelection(.enabled)
                .lineLimit(isExpanded ? nil : 1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

                if let durationText, !isExpanded {
                    Text(durationText)
                        .font(.caption2)
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            Capsule(style: .continuous)
                                .fill(statusColor.opacity(0.10))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(statusColor.opacity(0.22), lineWidth: 0.5)
                        )
                }

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private var statusColor: Color {
        switch message.detail.status {
        case .running:
            palette.accentPrimary
        case .completed:
            palette.textSecondary
        case .failed:
            palette.danger
        }
    }

    private var accessibilitySummary: String {
        let statusLabel = switch message.detail.status {
        case .running: "running"
        case .completed: "completed"
        case .failed: "failed"
        }
        return "\(display.verb) \(display.target), \(statusLabel)"
    }

    private func formattedDuration(_ ms: Int) -> String {
        if ms < 1000 { return "\(ms)ms" }
        let seconds = Double(ms) / 1000.0
        if seconds < 60 { return String(format: "%.1fs", seconds) }
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return "\(minutes)m \(remainingSeconds)s"
    }
}
