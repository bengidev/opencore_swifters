import Foundation

/// Encapsulates a single Settings flow mutation.
protocol SettingsCommand: Sendable {
    func execute(on state: inout SettingsFlowState)
}

/// Updates the draft API key from the text-field binding.
struct SettingsDraftChangedCommand: SettingsCommand {
    let draft: String

    init(_ draft: String) {
        self.draft = draft
    }

    func execute(on state: inout SettingsFlowState) {
        state.draftAPIKey = draft
    }
}

/// Updates context compaction enabled flag.
struct SettingsContextCompactionEnabledChangedCommand: SettingsCommand {
    let isEnabled: Bool

    func execute(on state: inout SettingsFlowState) {
        state.contextCompaction.isEnabled = isEnabled
    }
}

/// Updates context compaction trigger threshold percent.
struct SettingsContextCompactionThresholdChangedCommand: SettingsCommand {
    let percent: Int

    func execute(on state: inout SettingsFlowState) {
        state.contextCompaction.triggerThresholdPercent = percent
    }
}

/// Dispatches setting commands without exposing mutation rules to callers.
struct SettingsCommandInvoker: Sendable {
    func invoke(_ command: any SettingsCommand, on state: inout SettingsFlowState) {
        command.execute(on: &state)
    }
}
