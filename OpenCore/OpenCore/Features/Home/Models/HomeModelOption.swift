import Foundation

nonisolated struct HomeModelOption: Equatable, Identifiable, Sendable {
    let model: ChatModel
    let availableSpeedModes: [HomeComposerSpeedMode]

    var id: String { model.id }
    var title: String { model.displayName }
    var isFree: Bool { model.isFree }
    var contextLength: Int? { model.contextLength }
    var supportsReasoning: Bool { model.supportsReasoning }

    init(model: ChatModel) {
        self.model = model
        self.availableSpeedModes = model.supportsSpeedModes ? HomeComposerSpeedMode.allCases : []
    }
}
