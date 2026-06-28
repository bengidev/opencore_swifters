import Foundation

nonisolated enum ChatStreamingEvent: Equatable, Sendable {
    case textDelta(String)
    case thinkingDelta(String)
    case outputStreamBegan(command: String, cwd: String?)
    case outputStreamDelta(String)
    case outputStreamEnded(
        status: ChatOutputStreamStatus,
        exitCode: Int?,
        durationMs: Int?
    )
    case done
    case error(ChatStreamError)
}
