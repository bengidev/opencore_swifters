import Foundation
import Testing

@testable import OpenCore

@Suite("Vision Plain Text Extractor")
struct VisionPlainTextExtractorTests {
    @Test("decodes UTF-8 text files")
    func decodesUTF8() throws {
        let data = Data("Hello, OpenCore.".utf8)

        let extracted = try VisionPlainTextExtractor.extract(from: data)

        #expect(extracted == "Hello, OpenCore.")
    }

    @Test("rejects files above the byte limit")
    func rejectsOversizedFiles() {
        let oversized = Data(repeating: 0x41, count: VisionPlainTextExtractor.maxByteCount + 1)

        #expect(throws: VisionExtractionError.fileTooLarge) {
            try VisionPlainTextExtractor.extract(from: oversized)
        }
    }

    @Test("rejects invalid UTF-8 payloads")
    func rejectsInvalidUTF8() {
        let invalid = Data([0xFF, 0xFE, 0xFD])

        #expect(throws: VisionExtractionError.unreadableContent) {
            try VisionPlainTextExtractor.extract(from: invalid)
        }
    }
}
