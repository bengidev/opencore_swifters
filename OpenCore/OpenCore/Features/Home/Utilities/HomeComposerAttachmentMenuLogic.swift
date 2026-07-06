import Foundation

nonisolated enum HomeComposerAttachmentMenuLogic: Sendable {
    enum MenuOption: Equatable, Sendable {
        case importFile
        case photoLibrary
    }

    enum PlusButtonState: Equatable, Sendable {
        case hidden
        case loading
        case available(ModelInputCapabilities)
    }

    static func plusButtonState(
        isLoading: Bool,
        capabilities: ModelInputCapabilities?
    ) -> PlusButtonState {
        if isLoading { return .loading }
        guard let capabilities, capabilities.supportsAttachments else { return .hidden }
        return .available(capabilities)
    }

    static func menuOptions(for capabilities: ModelInputCapabilities) -> [MenuOption] {
        var options: [MenuOption] = []
        if capabilities.supportsFileInput { options.append(.importFile) }
        if capabilities.supportsImageInput || capabilities.supportsVideoInput {
            options.append(.photoLibrary)
        }
        return options
    }
}
