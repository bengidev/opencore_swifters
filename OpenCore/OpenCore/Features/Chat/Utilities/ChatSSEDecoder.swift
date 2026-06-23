import Foundation

/// Networking primitive for SSE line parsing. Knows nothing about chat
/// vocabulary — buffers raw bytes, splits on newlines, and interprets each
/// line under the SSE wire rules.
nonisolated struct ChatSSEDecoder: Sendable {
    static let doneSentinel = "[DONE]"

    enum Event: Equatable, Sendable {
        case data(String)
        case done
    }

    private var buffer: [UInt8] = []
    private let newline = UInt8(ascii: "\n")

    init() {}

    mutating func append(_ data: Data) -> [Event] {
        buffer.append(contentsOf: data)

        var events: [Event] = []
        var lineStart = 0
        var index = 0
        while index < buffer.count {
            if buffer[index] == newline {
                let lineBytes = buffer[lineStart..<index]
                let rawLine = String(bytes: lineBytes, encoding: .utf8) ?? ""
                if let event = Self.interpret(rawLine) {
                    events.append(event)
                }
                lineStart = index + 1
            }
            index += 1
        }

        if lineStart > 0 {
            buffer.removeFirst(lineStart)
        }
        return events
    }

    static func interpret(_ rawLine: String) -> Event? {
        let line = rawLine.hasSuffix("\r") ? String(rawLine.dropLast()) : rawLine

        if line.isEmpty { return nil }
        if line.hasPrefix(":") { return nil }
        guard line.hasPrefix("data:") else { return nil }

        var payload = String(line.dropFirst("data:".count))
        if payload.hasPrefix(" ") { payload.removeFirst() }

        if payload == doneSentinel { return .done }
        return .data(payload)
    }
}
