import Foundation
import SwiftData

enum PersistenceSwiftDataAtomMigrationSupport {
    static func chatMessage(from entity: AtomMessageEntity) -> ChatMessage? {
        let kind = ChatMessageKind(rawValue: entity.kindRaw) ?? .text
        let role = ChatMessageRole(rawValue: entity.role) ?? .assistant

        switch kind {
        case .text:
            let detail = Self.decodeTextMessageDetail(from: entity.detailJSON)
            return .text(
                id: entity.id,
                role: role,
                content: entity.content,
                isComplete: entity.isComplete,
                timestamp: entity.timestamp,
                attachments: detail?.attachments ?? [],
                modelContent: detail?.modelContent
            )
        case .thinking:
            return .thinking(
                id: entity.id,
                content: entity.content,
                isComplete: entity.isComplete,
                timestamp: entity.timestamp
            )
        case .system:
            return .system(id: entity.id, content: entity.content, timestamp: entity.timestamp)
        case .outputStream:
            let detail = Self.decodeOutputStreamDetail(
                from: entity.detailJSON,
                isComplete: entity.isComplete
            )
            return .outputStream(
                id: entity.id,
                command: entity.content,
                detail: detail,
                isComplete: entity.isComplete,
                timestamp: entity.timestamp
            )
        }
    }

    @MainActor
    private static func entity(from message: ChatMessage, order: Int) -> AtomMessageEntity {
        switch message {
        case let .text(text):
            return AtomMessageEntity(
                id: text.id,
                kindRaw: ChatMessageKind.text.rawValue,
                role: text.role.rawValue,
                content: text.content,
                isComplete: text.isComplete,
                timestamp: text.timestamp,
                order: order,
                detailJSON: Self.encodeTextMessageDetail(
                    attachments: text.attachments,
                    modelContent: text.modelContent
                )
            )
        case let .thinking(thinking):
            return AtomMessageEntity(
                id: thinking.id,
                kindRaw: ChatMessageKind.thinking.rawValue,
                role: thinking.role.rawValue,
                content: thinking.content,
                isComplete: thinking.isComplete,
                timestamp: thinking.timestamp,
                order: order
            )
        case let .system(system):
            return AtomMessageEntity(
                id: system.id,
                kindRaw: ChatMessageKind.system.rawValue,
                role: system.role.rawValue,
                content: system.content,
                isComplete: true,
                timestamp: system.timestamp,
                order: order
            )
        case let .outputStream(outputStream):
            return AtomMessageEntity(
                id: outputStream.id,
                kindRaw: ChatMessageKind.outputStream.rawValue,
                role: outputStream.role.rawValue,
                content: outputStream.command,
                isComplete: outputStream.isComplete,
                timestamp: outputStream.timestamp,
                order: order,
                detailJSON: Self.encodeOutputStreamDetail(outputStream.detail)
            )
        }
    }

    @MainActor
    private static func apply(_ message: ChatMessage, to entity: AtomMessageEntity) {
        switch message {
        case let .text(text):
            entity.kindRaw = ChatMessageKind.text.rawValue
            entity.role = text.role.rawValue
            entity.content = text.content
            entity.isComplete = text.isComplete
            entity.timestamp = text.timestamp
            entity.detailJSON = Self.encodeTextMessageDetail(
                attachments: text.attachments,
                modelContent: text.modelContent
            )
        case let .thinking(thinking):
            entity.kindRaw = ChatMessageKind.thinking.rawValue
            entity.role = thinking.role.rawValue
            entity.content = thinking.content
            entity.isComplete = thinking.isComplete
            entity.timestamp = thinking.timestamp
        case let .system(system):
            entity.kindRaw = ChatMessageKind.system.rawValue
            entity.role = system.role.rawValue
            entity.content = system.content
            entity.isComplete = true
            entity.timestamp = system.timestamp
            entity.detailJSON = nil
        case let .outputStream(outputStream):
            entity.kindRaw = ChatMessageKind.outputStream.rawValue
            entity.role = outputStream.role.rawValue
            entity.content = outputStream.command
            entity.isComplete = outputStream.isComplete
            entity.timestamp = outputStream.timestamp
            entity.detailJSON = Self.encodeOutputStreamDetail(outputStream.detail)
        }
    }

    @MainActor
    private static func encodeTextMessageDetail(
        attachments: [ChatMessageAttachment],
        modelContent: String?
    ) -> String? {
        guard !attachments.isEmpty || modelContent != nil else { return nil }
        let detail = ChatTextMessageDetail(attachments: attachments, modelContent: modelContent)
        guard let data = try? JSONEncoder().encode(detail) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @MainActor
    private static func decodeTextMessageDetail(from json: String?) -> ChatTextMessageDetail? {
        guard let json,
              let data = json.data(using: .utf8),
              let detail = try? JSONDecoder().decode(ChatTextMessageDetail.self, from: data) else {
            return nil
        }
        return detail
    }

    @MainActor
    private static func encodeOutputStreamDetail(_ detail: ChatOutputStreamDetail) -> String? {
        guard let data = try? JSONEncoder().encode(detail) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @MainActor
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
