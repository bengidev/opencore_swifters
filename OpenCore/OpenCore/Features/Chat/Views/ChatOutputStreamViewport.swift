import SwiftUI

/// Presentation rules for litter-style command output viewports.
nonisolated enum ChatOutputStreamViewportPresentation {
    static let maxVisibleCharacters = 2_000
    /// Caps the viewport scroll region height; character truncation is handled separately.
    static let maxVisibleLines = 3

    static func renderedOutput(output: String, isInProgress: Bool) -> String {
        let trimmed = output.trimmingCharacters(in: .newlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return isInProgress ? "Waiting for output…" : "No output"
    }

    static func shouldLimitOutput(_ output: String) -> Bool {
        output.count > maxVisibleCharacters
    }

    static func usesTailPreview(isInProgress: Bool) -> Bool {
        isInProgress
    }

    static func visibleOutput(
        output: String,
        isInProgress: Bool,
        isLongOutputExpanded: Bool
    ) -> String {
        guard shouldLimitOutput(output), !isLongOutputExpanded else {
            return output
        }
        if usesTailPreview(isInProgress: isInProgress) {
            return String(output.suffix(maxVisibleCharacters))
        }
        return String(output.prefix(maxVisibleCharacters))
    }

    /// Returns whether long-output expansion should collapse after an output update.
    static func shouldCollapseLongOutputExpansion(
        previousOutput: String,
        newOutput: String,
        isInProgress: Bool
    ) -> Bool {
        let previousRendered = renderedOutput(output: previousOutput, isInProgress: isInProgress)
        let newRendered = renderedOutput(output: newOutput, isInProgress: isInProgress)
        return !shouldLimitOutput(previousRendered) && shouldLimitOutput(newRendered)
    }
}

/// Three-line capped scroll region for live command output, modeled on litter's viewport.
struct ChatOutputStreamViewport: View {
    let output: String
    let status: ChatOutputStreamStatus
    let durationText: String?
    let exitCode: Int?

    @Environment(\.sharedPalette) private var palette
    @State private var expandedLongOutput = false

    private let bottomAnchorID = "chat-output-stream-bottom"
    private let lineFontSize: CGFloat = 12

    init(
        output: String,
        status: ChatOutputStreamStatus,
        durationText: String? = nil,
        exitCode: Int? = nil
    ) {
        self.output = output
        self.status = status
        self.durationText = durationText
        self.exitCode = exitCode
    }

    private var isInProgress: Bool {
        status == .running
    }

    private var visibleOutput: String {
        ChatOutputStreamViewportPresentation.visibleOutput(
            output: renderedOutput,
            isInProgress: isInProgress,
            isLongOutputExpanded: expandedLongOutput
        )
    }

    private var renderedOutput: String {
        ChatOutputStreamViewportPresentation.renderedOutput(
            output: output,
            isInProgress: isInProgress
        )
    }

    private var shouldLimitOutput: Bool {
        ChatOutputStreamViewportPresentation.shouldLimitOutput(renderedOutput)
    }

    private var maxViewportHeight: CGFloat {
        (UIFont.monospacedSystemFont(ofSize: lineFontSize, weight: .regular).lineHeight * CGFloat(ChatOutputStreamViewportPresentation.maxVisibleLines)) + 16
    }

    private var viewportHeight: CGFloat {
        let lineHeight = UIFont.monospacedSystemFont(ofSize: lineFontSize, weight: .regular).lineHeight
        let lines = max(1, visibleOutput.split(separator: "\n", omittingEmptySubsequences: false).count)
        let natural = (lineHeight * CGFloat(min(lines, ChatOutputStreamViewportPresentation.maxVisibleLines))) + 16
        return min(natural, maxViewportHeight)
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 6) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(verbatim: visibleOutput)
                            .font(SharedOpenCoreTypography.monoSM)
                            .foregroundStyle(palette.textSecondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel(outputAccessibilityLabel)

                        Color.clear
                            .frame(height: 1)
                            .id(bottomAnchorID)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }
                .frame(height: viewportHeight)
                .background(palette.surfaceRaised.opacity(0.78))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [
                            palette.surfaceRaised.opacity(0.96),
                            palette.surfaceRaised.opacity(0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .bottomTrailing) {
                    HStack(spacing: 6) {
                        if let exitCode, status == .failed {
                            Text("exit \(exitCode)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(exitCode == 0 ? palette.textSecondary : palette.danger)
                                .accessibilityLabel("Exit code \(exitCode)")
                        }
                        if let durationText, !durationText.isEmpty {
                            Text(durationText)
                                .font(.caption2)
                                .foregroundStyle(statusColor)
                                .accessibilityLabel(durationAccessibilityLabel(durationText))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(alignment: .bottom) {
                        LinearGradient(
                            colors: [.clear, palette.surfaceRaised.opacity(0.94)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(palette.textTertiary.opacity(0.35), lineWidth: 1)
                }
                .onAppear {
                    scrollToBottom(proxy)
                }
                .onChange(of: output) { previousOutput, newOutput in
                    if ChatOutputStreamViewportPresentation.shouldCollapseLongOutputExpansion(
                        previousOutput: previousOutput,
                        newOutput: newOutput,
                        isInProgress: isInProgress
                    ) {
                        expandedLongOutput = false
                    }
                    scrollToBottom(proxy, animated: true)
                }
                .onChange(of: status) { _, _ in
                    expandedLongOutput = false
                }
                .onChange(of: expandedLongOutput) { _, _ in
                    scrollToBottom(proxy, animated: true)
                }

                if shouldLimitOutput {
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) {
                            expandedLongOutput.toggle()
                        }
                    } label: {
                        Text(expandedLongOutput ? "Show less" : "Show more")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(palette.accentPrimary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        expandedLongOutput ? "Show less command output" : "Show more command output"
                    )
                }
            }
        }
    }

    private var outputAccessibilityLabel: String {
        switch renderedOutput {
        case "Waiting for output…", "No output":
            renderedOutput
        default:
            if shouldLimitOutput, !expandedLongOutput {
                "Command output, truncated"
            } else {
                "Command output"
            }
        }
    }

    private var statusColor: Color {
        switch status {
        case .running:
            palette.accentPrimary
        case .completed:
            palette.textSecondary
        case .failed:
            palette.danger
        }
    }

    private func durationAccessibilityLabel(_ duration: String) -> String {
        switch status {
        case .completed:
            "\(duration), completed"
        case .running:
            "\(duration), in progress"
        case .failed:
            "\(duration), failed"
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = false) {
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.16)) {
                    proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(bottomAnchorID, anchor: .bottom)
            }
        }
    }
}
