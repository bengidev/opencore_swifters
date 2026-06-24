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

    init(id: String, title: String) {
        self.model = ChatModel(id: id, displayName: title)
        self.availableSpeedModes = []
    }
}

enum HomeModelCatalog {
    nonisolated static func models(for providerID: String?) -> [HomeModelOption] {
        ChatModel.curatedFallback(for: providerID).map { HomeModelOption(model: $0) }
    }

    nonisolated static func displayTitle(for modelID: String) -> String {
        let leaf = modelID.split(separator: "/").last.map(String.init) ?? modelID
        let withoutFreeSuffix = leaf.replacingOccurrences(of: ":free", with: "")
        return withoutFreeSuffix
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
    }
}
