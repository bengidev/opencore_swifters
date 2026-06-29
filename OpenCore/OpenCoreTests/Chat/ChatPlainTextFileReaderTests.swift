import Foundation
import Testing

@testable import OpenCore

@Suite("Chat Plain Text File Reader")
struct ChatPlainTextFileReaderTests {
    @Test("extracts UTF-8 text")
    func extractsText() throws {
        let data = Data("Hello from file".utf8)
        let extracted = try ChatPlainTextFileReader.read(from: data)
        #expect(extracted == "Hello from file")
    }

    @Test("rejects oversized files")
    func rejectsOversizedFiles() {
        let oversized = Data(repeating: 0x41, count: ChatPlainTextFileReader.maxByteCount + 1)
        #expect(throws: ChatAttachmentError.fileTooLarge) {
            try ChatPlainTextFileReader.read(from: oversized)
        }
    }

    @Test("rejects invalid UTF-8")
    func rejectsInvalidUTF8() {
        let invalid = Data([0xFF, 0xFE, 0xFD])
        #expect(throws: ChatAttachmentError.unreadableFile) {
            try ChatPlainTextFileReader.read(from: invalid)
        }
    }
}
