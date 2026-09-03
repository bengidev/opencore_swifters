import Foundation

/// Encodes and decodes `ChatMessage` values for GRDB session entry payloads.
@MainActor
enum AtomSessionMessageCodec {
    private struct StoredMessage: Codable {
        let kindRaw: String
        let role: String
        let content: String
        let isComplete: Bool
        let timestamp: Date
        let detailJSON: String?
    }

    static func encode(_ message: ChatMessage) throws -> Data {
        let stored = storedMessage(from: message)
        return try JSONEncoder().encode(stored)
    }

    static func decode(data: Data, messageID: UUID) throws -> ChatMessage {
        let stored = try JSONDecoder().decode(StoredMessage.self, from: data)
        return try chatMessage(from: stored, messageID: messageID)
    }

    static func encodeCompaction(_ checkpoint: AtomCompactionCheckpoint) throws -> Data {
        try JSONEncoder().encode(checkpoint)
    }

    static func decodeCompaction(data: Data) throws -> AtomCompactionCheckpoint {
        try JSONDecoder().decode(AtomCompactionCheckpoint.self, from: data)
    }

    private static func storedMessage(from message: ChatMessage) -> StoredMessage {
        switch message {
        case let .text(text):
            return StoredMessage(
                kindRaw: ChatMessageKind.text.rawValue,
                role: text.role.rawValue,
                content: text.content,
                isComplete: text.isComplete,
                timestamp: text.timestamp,
                detailJSON: encodeTextDetail(attachments: text.attachments, modelContent: text.modelContent)
            )
        case let .thinking(thinking):
            return StoredMessage(
                kindRaw: ChatMessageKind.thinking.rawValue,
                role: thinking.role.rawValue,
                content: thinking.content,
                isComplete: thinking.isComplete,
                timestamp: thinking.timestamp,
                detailJSON: nil
            )
        case let .system(system):
            return StoredMessage(
                kindRaw: ChatMessageKind.system.rawValue,
                role: system.role.rawValue,
                content: system.content,
                isComplete: true,
                timestamp: system.timestamp,
                detailJSON: nil
            )
        case let .outputStream(outputStream):
            return StoredMessage(
                kindRaw: ChatMessageKind.outputStream.rawValue,
                role: outputStream.role.rawValue,
                content: outputStream.command,
                isComplete: outputStream.isComplete,
                timestamp: outputStream.timestamp,
                detailJSON: encodeOutputStreamDetail(outputStream.detail)
            )
        }
    }

    private static func chatMessage(from stored: StoredMessage, messageID: UUID) throws -> ChatMessage {
        let kind = ChatMessageKind(rawValue: stored.kindRaw) ?? .text
        let role = ChatMessageRole(rawValue: stored.role) ?? .assistant

        switch kind {
        case .text:
            let detail = decodeTextDetail(from: stored.detailJSON)
            return .text(
                id: messageID,
                role: role,
                content: stored.content,
                isComplete: stored.isComplete,
                timestamp: stored.timestamp,
                attachments: detail?.attachments ?? [],
                modelContent: detail?.modelContent
            )
        case .thinking:
            return .thinking(
                id: messageID,
                role: role,
                content: stored.content,
                isComplete: stored.isComplete,
                timestamp: stored.timestamp
            )
        case .system:
            return .system(id: messageID, content: stored.content, timestamp: stored.timestamp)
        case .outputStream:
            let detail = decodeOutputStreamDetail(from: stored.detailJSON, isComplete: stored.isComplete)
            return .outputStream(
                id: messageID,
                command: stored.content,
                detail: detail,
                isComplete: stored.isComplete,
                timestamp: stored.timestamp
            )
        }
    }

    private static func encodeTextDetail(
        attachments: [ChatMessageAttachment],
        modelContent: String?
    ) -> String? {
        guard !attachments.isEmpty || modelContent != nil else { return nil }
        let detail = ChatTextMessageDetail(attachments: attachments, modelContent: modelContent)
        guard let data = try? JSONEncoder().encode(detail) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func decodeTextDetail(from json: String?) -> ChatTextMessageDetail? {
        guard let json,
              let data = json.data(using: .utf8),
              let detail = try? JSONDecoder().decode(ChatTextMessageDetail.self, from: data) else {
            return nil
        }
        return detail
    }

    private static func encodeOutputStreamDetail(_ detail: ChatOutputStreamDetail) -> String? {
        guard let data = try? JSONEncoder().encode(detail) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func decodeOutputStreamDetail(
        from json: String?,
        isComplete: Bool
    ) -> ChatOutputStreamDetail {
        guard let json,
              let data = json.data(using: .utf8),
              let detail = try? JSONDecoder().decode(ChatOutputStreamDetail.self, from: data) else {
            return ChatOutputStreamDetail(status: isComplete ? .completed : .running)
        }
        return detail
    }
}
