import Foundation

/// Adapter contract for an external AI provider. Encodes requests and
/// exposes capability flags so feature code never branches on provider ids.
nonisolated protocol ProviderAdapting: Sendable {
    var descriptor: ProviderDescriptor { get }
    var supportsProviderRouting: Bool { get }

    func makeChatCompletionURLRequest(secret: String, chatRequest: ChatRequest) throws -> URLRequest
    func makeModelsListURLRequest(secret: String) -> URLRequest
    func makeModelDetailURLRequest(modelID: String, secret: String) -> URLRequest?
}
