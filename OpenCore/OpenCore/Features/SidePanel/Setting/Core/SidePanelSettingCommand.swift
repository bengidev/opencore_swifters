import Foundation

/// Encapsulates a single Settings flow mutation.
protocol SidePanelSettingCommand: Sendable {
    func execute(on state: inout SidePanelSettingFlowState)
}

/// Updates the draft API key from the text-field binding.
struct SidePanelSettingDraftChangedCommand: SidePanelSettingCommand {
    let draft: String

    init(_ draft: String) {
        self.draft = draft
    }

    func execute(on state: inout SidePanelSettingFlowState) {
        state.draftAPIKey = draft
    }
}

/// Dispatches setting commands without exposing mutation rules to callers.
struct SidePanelSettingCommandInvoker: Sendable {
    func invoke(_ command: any SidePanelSettingCommand, on state: inout SidePanelSettingFlowState) {
        command.execute(on: &state)
    }
}
