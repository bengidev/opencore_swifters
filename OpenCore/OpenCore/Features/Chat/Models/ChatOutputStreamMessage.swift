import Foundation

nonisolated enum ChatOutputStreamStatus: String, Equatable, Sendable, Codable {
    case running
    case completed
    case failed
}

nonisolated struct ChatOutputStreamDetail: Equatable, Sendable, Codable {
    var status: ChatOutputStreamStatus
    var outputTail: String
    var cwd: String?
    var exitCode: Int?
    var durationMs: Int?

    static let maxOutputLines = 30

    nonisolated init(
        status: ChatOutputStreamStatus = .running,
        outputTail: String = "",
        cwd: String? = nil,
        exitCode: Int? = nil,
        durationMs: Int? = nil
    ) {
        self.status = status
        self.outputTail = outputTail
        self.cwd = cwd
        self.exitCode = exitCode
        self.durationMs = durationMs
    }

    mutating func appendOutput(_ chunk: String) {
        outputTail += chunk
        trimOutputTail()
    }

    mutating func trimOutputTail() {
        let lines = outputTail.components(separatedBy: .newlines)
        if lines.count > Self.maxOutputLines {
            outputTail = lines.suffix(Self.maxOutputLines).joined(separator: "\n")
        }
    }
}

nonisolated struct ChatOutputStreamMessage: ChatMessagePayload, Equatable, Identifiable, Sendable, Codable {
    let id: UUID
    let role: ChatMessageRole
    var command: String
    var detail: ChatOutputStreamDetail
    var isComplete: Bool
    let timestamp: Date

    nonisolated init(
        id: UUID = UUID(),
        role: ChatMessageRole = .system,
        command: String,
        detail: ChatOutputStreamDetail = ChatOutputStreamDetail(),
        isComplete: Bool = false,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.command = command
        self.detail = detail
        self.isComplete = isComplete
        self.timestamp = timestamp
    }
}
