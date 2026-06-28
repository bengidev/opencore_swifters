import SwiftUI

/// Inline command output stream row with expandable detail sheet.
struct ChatOutputStreamCardView: View {
    let message: ChatOutputStreamMessage

    @Environment(\.sharedPalette) private var palette
    @State private var isShowingDetailSheet = false

    private var isRunning: Bool {
        message.detail.status == .running && !message.isComplete
    }

    private var display: ChatOutputStreamHumanizer.Info {
        ChatOutputStreamHumanizer.humanize(message.command, isRunning: isRunning)
    }

    private var statusLabel: String {
        switch message.detail.status {
        case .running: "running"
        case .completed: "completed"
        case .failed: "failed"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                (
                    Text(display.verb)
                        .font(SharedOpenCoreTypography.bodyMD)
                        .foregroundStyle(palette.textSecondary)
                    +
                    Text(" " + display.target)
                        .font(SharedOpenCoreTypography.bodyMD)
                        .foregroundStyle(palette.textTertiary)
                )
                .lineLimit(1)
                .truncationMode(.tail)

                Spacer(minLength: 6)

                Text(statusLabel)
                    .font(SharedOpenCoreTypography.bodyMD)
                    .foregroundStyle(statusColor.opacity(message.detail.status == .failed ? 1 : 0.5))

                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(palette.textTertiary.opacity(0.6))
                    .padding(.leading, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                isShowingDetailSheet = true
            }
            .transaction { transaction in
                transaction.animation = nil
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surfaceRaised.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(palette.textTertiary.opacity(0.12), lineWidth: 0.5)
        )
        .sheet(isPresented: $isShowingDetailSheet) {
            ChatOutputStreamDetailSheet(message: message)
                .presentationDetents([.fraction(0.35), .medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var statusColor: Color {
        switch message.detail.status {
        case .running:
            return palette.accentPrimary
        case .completed:
            return palette.textSecondary
        case .failed:
            return .red
        }
    }
}

private struct ChatOutputStreamDetailSheet: View {
    let message: ChatOutputStreamMessage

    @Environment(\.sharedPalette) private var palette
    @State private var isOutputExpanded = false

    private var isRunning: Bool {
        message.detail.status == .running && !message.isComplete
    }

    private var display: ChatOutputStreamHumanizer.Info {
        ChatOutputStreamHumanizer.humanize(message.command, isRunning: isRunning)
    }

    private var statusLabel: String {
        switch message.detail.status {
        case .running: "running"
        case .completed: "completed"
        case .failed: "failed"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                commandSection
                metadataSection
                if !message.detail.outputTail.isEmpty {
                    outputSection
                }
            }
            .padding()
        }
    }

    private var commandSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Command", systemImage: "terminal.fill")
                .font(SharedOpenCoreTypography.monoSM)
                .foregroundStyle(palette.accentPrimary)
                .monoTracking()

            Text(message.command)
                .font(SharedOpenCoreTypography.monoSM)
                .foregroundStyle(palette.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(palette.surfaceRaised)
                )
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            metadataRow(label: "Action", value: "\(display.verb) \(display.target)")
            if let cwd = message.detail.cwd, !cwd.isEmpty {
                metadataRow(label: "Directory", value: cwd)
            }
            if let exitCode = message.detail.exitCode {
                metadataRow(
                    label: "Exit code",
                    value: "\(exitCode)",
                    valueColor: exitCode == 0 ? .green : .red
                )
            }
            if let durationMs = message.detail.durationMs {
                metadataRow(label: "Duration", value: formattedDuration(durationMs))
            }
            metadataRow(label: "Status", value: statusLabel)
        }
    }

    private func metadataRow(
        label: String,
        value: String,
        valueColor: Color? = nil
    ) -> some View {
        HStack {
            Text(label)
                .font(SharedOpenCoreTypography.monoSM)
                .foregroundStyle(palette.textSecondary)
                .monoTracking()
            Spacer()
            Text(value)
                .font(SharedOpenCoreTypography.monoSM)
                .foregroundStyle(valueColor ?? palette.textPrimary)
                .textSelection(.enabled)
        }
    }

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isOutputExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isOutputExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Output (last \(ChatOutputStreamDetail.maxOutputLines) lines)")
                        .font(SharedOpenCoreTypography.monoSM)
                }
                .foregroundStyle(palette.textSecondary)
            }
            .buttonStyle(.plain)

            if isOutputExpanded {
                Text(message.detail.outputTail)
                    .font(SharedOpenCoreTypography.monoXS)
                    .foregroundStyle(palette.textSecondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(palette.surfaceRaised)
                    )
            }
        }
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
