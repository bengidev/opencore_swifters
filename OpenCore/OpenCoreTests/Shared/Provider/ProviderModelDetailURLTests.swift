import Foundation
import Testing
@testable import OpenCore

@Suite("Provider Model Detail URL")
struct ProviderModelDetailURLTests {
    @Test("OpenRouter builds model detail URL from id")
    func openRouterURL() {
        let adapter = ProviderOpenRouterAdapter()
        let request = adapter.makeModelDetailURLRequest(
            modelID: "openai/gpt-4o",
            secret: "sk-test"
        )
        #expect(request?.url?.absoluteString == "https://openrouter.ai/api/v1/model/openai/gpt-4o")
        #expect(request?.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
    }

    @Test("non-OpenRouter adapter returns nil")
    func genericAdapterNil() {
        let adapter = ProviderOpenAICompatibleAdapter(descriptor: .openCode)
        #expect(adapter.makeModelDetailURLRequest(modelID: "foo", secret: "key") == nil)
    }
}
