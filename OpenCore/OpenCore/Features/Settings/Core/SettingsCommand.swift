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

/// Updates context compaction reserve token headroom.
struct SettingsContextCompactionReserveTokensChangedCommand: SettingsCommand {
    let reserveTokens: Int

    func execute(on state: inout SettingsFlowState) {
        state.contextCompaction.reserveTokens = reserveTokens
    }
}

/// Updates how many recent tokens compaction keeps verbatim.
struct SettingsContextCompactionKeepRecentTokensChangedCommand: SettingsCommand {
    let keepRecentTokens: Int

    func execute(on state: inout SettingsFlowState) {
        state.contextCompaction.keepRecentTokens = keepRecentTokens
    }
}

/// Dispatches setting commands without exposing mutation rules to callers.
struct SettingsCommandInvoker: Sendable {
    func invoke(_ command: any SettingsCommand, on state: inout SettingsFlowState) {
        command.execute(on: &state)
    }
}
