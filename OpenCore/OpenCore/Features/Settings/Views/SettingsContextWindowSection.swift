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

    private var areCompactionTokenSlidersEnabled: Bool {
        !flow.state.contextCompaction.isEnabled
    }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Toggle(
                    "Automatic Compaction",
                    isOn: Binding(
                        get: { flow.state.contextCompaction.isEnabled },
                        set: { flow.setContextCompactionEnabled($0) }
                    )
                )
                .accessibilityIdentifier("settings-compaction-enabled")

                SettingsFormChrome.OptionDescription(
                    text: "Summarize older turns when context nears the model limit and reinject the summary so the session can continue."
                )
            }

            compactionTokenSlider(
                title: "Reserve Response Headroom",
                description: "Tokens held back for the model reply. Automatic compaction runs when usage exceeds the window minus this reserve.",
                value: reserveTokens,
                range: 4_096...32_768,
                step: 1_024,
                accessibilityID: "settings-compaction-reserve"
            ) { flow.setContextCompactionReserveTokens($0) }
            .disabled(!areCompactionTokenSlidersEnabled)

            compactionTokenSlider(
                title: "Keep Recent Context",
                description: "Recent turns kept verbatim during compaction. Everything older is summarized into the checkpoint.",
                value: keepRecentTokens,
                range: 4_096...40_960,
                step: 1_024,
                accessibilityID: "settings-compaction-keep-recent"
            ) { flow.setContextCompactionKeepRecentTokens($0) }
            .disabled(!areCompactionTokenSlidersEnabled)
        } header: {
            SettingsFormChrome.sectionHeader("Context Window")
        } footer: {
            SettingsFormChrome.SectionFooter(text: compactionFooterText)
        }
    }

    private func compactionTokenSlider(
        title: String,
        description: String,
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

            SettingsFormChrome.OptionDescription(text: description)
        }
        .accessibilityElement(children: .contain)
    }

    private var compactionFooterText: String {
        if flow.state.contextCompaction.isEnabled {
            return "Auto-compaction uses fixed reserve and keep-recent settings. Turn it off to adjust these values for manual compaction from the composer."
        }
        return "Reserve headroom and keep-recent settings apply to manual compaction from the composer."
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
