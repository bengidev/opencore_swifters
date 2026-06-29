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

    @Test("Catalog image modality enables image input support")
    func catalogImageModalityEnablesImageInput() throws {
        let json = Data("""
        {"id":"openai/gpt-4o","name":"GPT-4o","architecture":{"modality":"text+image"}}
        """.utf8)

        let model = try ProviderCatalogParser.chatModel(fromCatalogEntryJSON: json)

        #expect(model.supportsImageInput)
    }

    @Test("Catalog text-only modality disables image input support")
    func catalogTextOnlyModalityDisablesImageInput() throws {
        let json = Data("""
        {"id":"meta-llama/llama-3.3-70b-instruct:free","name":"Llama 3.3 70B","architecture":{"modality":"text"}}
        """.utf8)

        let model = try ProviderCatalogParser.chatModel(fromCatalogEntryJSON: json)

        #expect(!model.supportsImageInput)
        #expect(!model.supportsVideoInput)
    }

    @Test("Catalog video modality enables video input support")
    func catalogVideoModalityEnablesVideoInput() throws {
        let json = Data("""
        {"id":"google/gemini-2.5-flash","name":"Gemini 2.5 Flash","architecture":{"modality":"text+image+video"}}
        """.utf8)

        let model = try ProviderCatalogParser.chatModel(fromCatalogEntryJSON: json)

        #expect(model.supportsImageInput)
        #expect(model.supportsVideoInput)
    }
}
