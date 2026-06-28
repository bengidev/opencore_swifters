import Foundation

/// Maps provider SSE sideband payloads and command-output content parts
/// into chat output-stream events.
nonisolated enum ProviderStreamOutputEventMapper {
    static func mapSidebandPayload(_ data: Data) -> [ChatStreamingEvent]? {
        guard let envelope = try? JSONDecoder().decode(ProviderStreamSidebandEnvelope.self, from: data),
              let eventType = envelope.resolvedEventType?.lowercased()
        else { return nil }

        let body = envelope.resolvedBody
        switch eventType {
        case "exec_command_begin", "command_output_begin", "command_execution_begin", "output_stream_begin":
            guard let command = body.resolvedCommand?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !command.isEmpty else { return nil }
            return [.outputStreamBegan(command: command, cwd: body.resolvedCWD)]

        case "exec_command_output_delta", "command_output_delta", "command_execution_output_delta", "output_stream_delta":
            guard let delta = body.resolvedOutputDelta, !delta.isEmpty else { return nil }
            return [.outputStreamDelta(delta)]

        case "exec_command_end", "command_output_end", "command_execution_end", "output_stream_end":
            return [
                .outputStreamEnded(
                    status: body.resolvedStatus,
                    exitCode: body.resolvedExitCode,
                    durationMs: body.resolvedDurationMs
                )
            ]

        default:
            return nil
        }
    }

    static func mapContentParts(_ parts: [ChatStreamContentPart]) -> [ChatStreamingEvent] {
        parts.flatMap(mapContentPart)
    }

    private static func mapContentPart(_ part: ChatStreamContentPart) -> [ChatStreamingEvent] {
        guard let type = part.type?.lowercased() else { return [] }

        switch type {
        case "exec_command_begin", "command_output_begin", "command_execution_begin", "output_stream_begin":
            guard let command = part.resolvedCommand?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !command.isEmpty else { return [] }
            return [.outputStreamBegan(command: command, cwd: part.cwd)]

        case "exec_command_output_delta", "command_output_delta", "command_execution_output_delta", "output_stream_delta":
            guard let delta = part.resolvedOutputDelta, !delta.isEmpty else { return [] }
            return [.outputStreamDelta(delta)]

        case "exec_command_end", "command_output_end", "command_execution_end", "output_stream_end":
            return [
                .outputStreamEnded(
                    status: part.resolvedStatus,
                    exitCode: part.resolvedExitCode,
                    durationMs: part.resolvedDurationMs
                )
            ]

        default:
            return []
        }
    }
}

nonisolated struct ProviderStreamSidebandBody: Decodable, Sendable {
    let type: String?
    let command: ProviderFlexibleCommand?
    let cwd: String?
    let chunk: String?
    let delta: String?
    let output: String?
    let text: String?
    let status: String?
    let exitCode: Int?
    let durationMs: Int?

    enum CodingKeys: String, CodingKey {
        case type, command, cwd, chunk, delta, output, text, status
        case exitCode = "exit_code"
        case durationMs = "duration_ms"
    }

    nonisolated var resolvedCommand: String? {
        command?.normalized
    }

    nonisolated var resolvedCWD: String? {
        let value = cwd?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty == false) ? value : nil
    }

    nonisolated var resolvedOutputDelta: String? {
        for candidate in [chunk, delta, output, text] {
            if let candidate, !candidate.isEmpty { return candidate }
        }
        return nil
    }

    nonisolated var resolvedExitCode: Int? { exitCode }

    nonisolated var resolvedDurationMs: Int? { durationMs }

    nonisolated var resolvedStatus: ChatOutputStreamStatus {
        let raw = status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch raw {
        case "failed", "error", "failure":
            return .failed
        case "completed", "complete", "success", "succeeded", "ok":
            return .completed
        default:
            if let exitCode, exitCode != 0 { return .failed }
            return .completed
        }
    }
}

nonisolated struct ProviderStreamSidebandEnvelope: Decodable, Sendable {
    let type: String?
    let command: ProviderFlexibleCommand?
    let cwd: String?
    let chunk: String?
    let delta: String?
    let output: String?
    let text: String?
    let status: String?
    let exitCode: Int?
    let durationMs: Int?
    let msg: ProviderStreamSidebandBody?
    let event: ProviderStreamSidebandBody?
    let choices: [ProviderChatCompletionsStreamChunk.Choice]?

    enum CodingKeys: String, CodingKey {
        case type, command, cwd, chunk, delta, output, text, status, msg, event, choices
        case exitCode = "exit_code"
        case durationMs = "duration_ms"
    }

    nonisolated var resolvedBody: ProviderStreamSidebandBody {
        if let msg { return msg }
        if let event { return event }
        return ProviderStreamSidebandBody(
            type: type,
            command: command,
            cwd: cwd,
            chunk: chunk,
            delta: delta,
            output: output,
            text: text,
            status: status,
            exitCode: exitCode,
            durationMs: durationMs
        )
    }

    nonisolated var resolvedEventType: String? {
        resolvedBody.type ?? type
    }
}

nonisolated struct ProviderFlexibleCommand: Decodable, Sendable, Equatable {
    let normalized: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            normalized = string
            return
        }
        if let argv = try? container.decode([String].self) {
            normalized = argv.joined(separator: " ")
            return
        }
        normalized = ""
    }
}

extension ChatStreamContentPart {
    nonisolated var resolvedCommand: String? {
        command?.normalized
    }

    nonisolated var resolvedOutputDelta: String? {
        for candidate in [chunk, delta, output, text] {
            if let candidate, !candidate.isEmpty { return candidate }
        }
        return nil
    }

    nonisolated var resolvedExitCode: Int? { exitCode }

    nonisolated var resolvedDurationMs: Int? { durationMs }

    nonisolated var resolvedStatus: ChatOutputStreamStatus {
        let raw = status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch raw {
        case "failed", "error", "failure":
            return .failed
        case "completed", "complete", "success", "succeeded", "ok":
            return .completed
        default:
            if let exitCode, exitCode != 0 { return .failed }
            return .completed
        }
    }
}
