import SwiftUI

/// Context window compaction controls for automatic and manual summarization.
struct SettingsContextWindowSection: View {
    @Bindable var flow: SettingsFlowController

    @Environment(\.sharedPalette) private var palette

    private var thresholdPercent: Int {
        flow.state.contextCompaction.triggerThresholdPercent
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

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Compact When Full") {
                    Text("\(thresholdPercent)%")
                        .foregroundStyle(palette.textPrimary)
                        .monospacedDigit()
                        .accessibilityIdentifier("settings-compaction-threshold-value")
                }

                Slider(
                    value: Binding(
                        get: { Double(thresholdPercent) },
                        set: { flow.setContextCompactionThresholdPercent(Int($0.rounded())) }
                    ),
                    in: Double(SettingsContextCompactionPreference.thresholdPercentRange.lowerBound)...Double(
                        SettingsContextCompactionPreference.thresholdPercentRange.upperBound
                    ),
                    step: 5
                )
                .accessibilityIdentifier("settings-compaction-threshold")

                SettingsFormChrome.OptionDescription(
                    text: "Start summarizing older turns once context use passes this level."
                )
            }
            .accessibilityElement(children: .contain)
        } header: {
            SettingsFormChrome.sectionHeader("Context Window")
        } footer: {
            SettingsFormChrome.SectionFooter(text: compactionFooterText)
        }
    }

    private var compactionFooterText: String {
        if flow.state.contextCompaction.isEnabled {
            return "Automatic compaction runs when context use passes this threshold. You can also compact manually from the composer."
        }
        return "This threshold applies when you compact context manually from the composer."
    }
}
