import SwiftUI

/// Context window compaction controls — threshold locked while automatic compaction runs.
struct SettingsContextWindowSection: View {
    @Bindable var flow: SettingsFlowController

    private var isThresholdEditable: Bool {
        !flow.state.contextCompaction.isEnabled
    }

    private var thresholdPercent: Int {
        flow.state.contextCompaction.triggerThresholdPercent
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
            SettingsFormChrome.sectionFooter(
                "Summarize older turns before the model context limit is reached."
            )
        }

        Section {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Compaction Threshold") {
                    HStack(spacing: 4) {
                        if !isThresholdEditable {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Text("\(thresholdPercent)%")
                            .foregroundStyle(isThresholdEditable ? .primary : .secondary)
                            .monospacedDigit()
                            .accessibilityIdentifier("settings-compaction-threshold-value")
                    }
                }

                Slider(
                    value: Binding(
                        get: { Double(thresholdPercent) },
                        set: { flow.setContextCompactionThresholdPercent(Int($0.rounded())) }
                    ),
                    in: 50...95,
                    step: 5
                )
                .disabled(!isThresholdEditable)
                .accessibilityIdentifier("settings-compaction-threshold")
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Compaction threshold")
            .accessibilityValue("\(thresholdPercent) percent")
            .accessibilityHint(
                isThresholdEditable
                    ? "Adjust when automatic compaction starts"
                    : "Turn off automatic compaction to change the threshold"
            )
        } footer: {
            SettingsFormChrome.sectionFooter(compactionFooterText)
        }
    }

    private var compactionFooterText: String {
        if flow.state.contextCompaction.isEnabled {
            return "Compaction runs at \(thresholdPercent)% of the model window. Turn off automatic compaction to adjust the threshold."
        }
        return "Set a threshold, then enable automatic compaction. Older messages are summarized into a system note."
    }
}
