import Foundation
import Testing

@testable import OpenCore

@Suite("Chat SSE Decoder")
struct ChatSSEDecoderTests {
    @Test("Interprets data lines and done sentinel")
    func interpretLines() {
        #expect(ChatSSEDecoder.interpret("data: hello") == .data("hello"))
        #expect(ChatSSEDecoder.interpret("data: [DONE]") == .done)
        #expect(ChatSSEDecoder.interpret(": keep-alive") == nil)
        #expect(ChatSSEDecoder.interpret("") == nil)
    }

    @Test("Buffers partial lines across chunks")
    func buffersPartialLines() {
        var decoder = ChatSSEDecoder()
        let first = decoder.append(Data("data: hel".utf8))
        #expect(first.isEmpty)

        let second = decoder.append(Data("lo\n".utf8))
        #expect(second == [.data("hello")])
    }

    @Test("Strips CRLF line endings")
    func crlf() {
        #expect(ChatSSEDecoder.interpret("data: ok\r") == .data("ok"))
    }
}
