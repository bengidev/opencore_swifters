import Foundation

/// Registry (factory) for registered AI provider adapters.
nonisolated enum ProviderRegistry {
    private nonisolated static let openRouter = ProviderOpenRouterAdapter()
    private nonisolated static let openCode = ProviderOpenAICompatibleAdapter(descriptor: .openCode)
    private nonisolated static let commandCode = ProviderOpenAICompatibleAdapter(descriptor: .commandCode)
    private nonisolated static let ollamaCloud = ProviderOpenAICompatibleAdapter(descriptor: .ollamaCloud)

    nonisolated static let defaultAdapter: any ProviderAdapting = openRouter

    nonisolated static var all: [any ProviderAdapting] {
        [openRouter, openCode, commandCode, ollamaCloud]
    }

    nonisolated static func resolve(id: String?) -> any ProviderAdapting {
        guard let id else { return defaultAdapter }
        return all.first { $0.descriptor.id == id } ?? defaultAdapter
    }

    /// All provider descriptors for settings UI.
    nonisolated static var allDescriptors: [ProviderDescriptor] {
        all.map(\.descriptor)
    }
}
