import Foundation

nonisolated struct HomeModelOption: Equatable, Identifiable, Sendable {
    let model: ChatModel
    let availableSpeedModes: [HomeComposerSpeedMode]
    let availableReasoningEfforts: [ModelReasoningEffort]

    var id: String { model.id }
    var title: String { model.displayName }
    var isFree: Bool { model.isFree }
    var contextLength: Int? { model.contextLength }
    var supportsReasoning: Bool { !availableReasoningEfforts.isEmpty }

    init(model: ChatModel, providerSupportsRouting: Bool = true) {
        self.model = model
        self.availableSpeedModes = model.supportsSpeedModes && providerSupportsRouting
            ? HomeComposerSpeedMode.allCases
            : []
        self.availableReasoningEfforts = ModelReasoningEffort.catalogOptions(
            from: model.supportedReasoningEfforts,
            reasoningMandatory: model.reasoningMandatory
        )
    }

    func resolvedReasoningEffort(storedWireValue: String?) -> ModelReasoningEffort {
        ModelReasoningEffort.resolvedSelection(
            storedWireValue: storedWireValue,
            available: availableReasoningEfforts
        )
    }
}
