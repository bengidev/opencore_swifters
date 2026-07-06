import Foundation
import Testing

@testable import OpenCore

@Suite("Home Model Capability Client")
struct HomeModelCapabilityClientTests {
    @Test("uses catalog fallback when adapter has no detail URL")
    func catalogFallback() async {
        let model = ChatModel(
            id: "claude-sonnet",
            displayName: "Claude",
            supportsImageInput: true
        )
        let client = HomeModelCapabilityClient.live
        let caps = await client.fetchCapabilities(
            ProviderDescriptor.openCode.id,
            model.id,
            "key",
            model,
            .shared
        )
        #expect(caps.supportsImageInput)
    }

    @Test("parses OpenRouter detail response")
    func parsesDetailResponse() async throws {
        let json = """
        {"data":{"id":"openai/gpt-4o","name":"GPT-4o","architecture":{"input_modalities":["text","file","image"]}}}
        """.data(using: .utf8)!
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = { _ in
            (
                HTTPURLResponse(
                    url: URL(string: "https://openrouter.ai")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                json
            )
        }
        let session = URLSession(configuration: config)
        let client = HomeModelCapabilityClient.live
        let caps = await client.fetchCapabilities(
            ProviderDescriptor.openRouter.id,
            "openai/gpt-4o",
            "sk-test",
            nil,
            session
        )
        #expect(caps.supportsFileInput)
        #expect(caps.supportsImageInput)
    }
}

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
