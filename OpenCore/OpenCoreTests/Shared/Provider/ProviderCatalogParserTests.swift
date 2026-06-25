import Foundation
import Testing

@testable import OpenCore

@Suite("Provider Catalog Parser")
struct ProviderCatalogParserTests {
    @Test("Catalog entry parses supported reasoning efforts")
    func catalogParsesSupportedReasoningEfforts() throws {
        let json = Data("""
        {"id":"openai/o4-mini","name":"O4 Mini","supported_parameters":["reasoning"],"reasoning":{"supported_efforts":["high","medium","low","none"],"mandatory":false}}
        """.utf8)

        let model = try ProviderCatalogParser.chatModel(fromCatalogEntryJSON: json)

        #expect(model.supportedReasoningEfforts == ["high", "medium", "low", "none"])
        #expect(!model.reasoningMandatory)
    }

    @Test("Catalog router entry enables speed modes")
    func catalogRouterEntryEnablesSpeedModes() throws {
        let json = Data("""
        {"id":"openrouter/free","name":"Free Models Router","architecture":{"tokenizer":"Router"}}
        """.utf8)

        let model = try ProviderCatalogParser.chatModel(fromCatalogEntryJSON: json)

        #expect(model.supportsSpeedModes)
    }

    @Test("Catalog standard entry hides speed modes")
    func catalogStandardEntryHidesSpeedModes() throws {
        let json = Data("""
        {"id":"meta-llama/llama-3.3-70b-instruct:free","name":"Llama 3.3 70B","architecture":{"tokenizer":"Llama3"}}
        """.utf8)

        let model = try ProviderCatalogParser.chatModel(fromCatalogEntryJSON: json)

        #expect(!model.supportsSpeedModes)
    }
}
