import SwiftUI

/// Context window compaction controls aligned with pi.dev reserve/keep token settings.
struct SettingsContextWindowSection: View {
    @Bindable var flow: SettingsFlowController

    @Environment(\.sharedPalette) private var palette

    private var reserveTokens: Int {
        flow.state.contextCompaction.reserveTokens
    }

    private var keepRecentTokens: Int {
        flow.state.contextCompaction.keepRecentTokens
    }

    var body: some View {
        Section {
            Toggle(
                "Automatic Compaction",
                isOn: Binding(
                    get: { flow.state.contextCompaction.isEnabled },
                    set: { flow.setContextCompactionEnabled($0) }
                )
            )
            .accessibilityIdentifier("settings-compaction-enabled")
        } header: {
            SettingsFormChrome.sectionHeader("Context Window")
        } footer: {
            SettingsFormChrome.SectionFooter(
                text: "Summarize older turns and reinject the summary so the model keeps context without exceeding its window."
            )
        }

        Section {
            compactionTokenSlider(
                title: "Reserve Response Headroom",
                value: reserveTokens,
                range: 4_096...32_768,
                step: 1_024,
                accessibilityID: "settings-compaction-reserve"
            ) { flow.setContextCompactionReserveTokens($0) }

            compactionTokenSlider(
                title: "Keep Recent Context",
                value: keepRecentTokens,
                range: 4_096...40_960,
                step: 1_024,
                accessibilityID: "settings-compaction-keep-recent"
            ) { flow.setContextCompactionKeepRecentTokens($0) }
        } footer: {
            SettingsFormChrome.SectionFooter(text: compactionFooterText)
        }
    }

    private func compactionTokenSlider(
        title: String,
        value: Int,
        range: ClosedRange<Double>,
        step: Double,
        accessibilityID: String,
        onChange: @escaping (Int) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent(title) {
                Text(formattedTokenCount(value))
                    .foregroundStyle(palette.textPrimary)
                    .monospacedDigit()
                    .accessibilityIdentifier("\(accessibilityID)-value")
            }

            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { onChange(Int($0.rounded())) }
                ),
                in: range,
                step: step
            )
            .accessibilityIdentifier(accessibilityID)
        }
        .accessibilityElement(children: .contain)
    }

    private var compactionFooterText: String {
        if flow.state.contextCompaction.isEnabled {
            return "Auto-compaction runs when context exceeds the model window minus \(formattedTokenCount(reserveTokens)) reserved for the reply. Up to \(formattedTokenCount(keepRecentTokens)) of recent turns stay verbatim."
        }
        return "Enable automatic compaction to summarize older history when context exceeds the model window minus the reserve headroom. Manual compaction remains available from the composer."
    }

    private func formattedTokenCount(_ value: Int) -> String {
        if value >= 1_000 {
            let thousands = Double(value) / 1_000.0
            if thousands.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(thousands))k tokens"
            }
            return String(format: "%.1fk tokens", thousands)
        }
        return "\(value) tokens"
    }
}
