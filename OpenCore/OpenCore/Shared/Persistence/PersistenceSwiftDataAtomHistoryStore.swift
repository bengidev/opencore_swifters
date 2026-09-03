import Foundation
import SwiftData

extension PersistenceAtomHistoryStore {
    @MainActor
    static func live(modelContainer: ModelContainer) -> Self {
        Self(
            listAtomEntries: { @MainActor in
                let context = ModelContext(modelContainer)
                let descriptor = FetchDescriptor<AtomEntity>(
                    sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
                )
                let mapped = try context.fetch(descriptor)
                    .map(Self.listEntry(from:))
                    .sorted { lhs, rhs in
                        if lhs.atom.isPinned != rhs.atom.isPinned { return lhs.atom.isPinned }
                        return lhs.lastMessageAt > rhs.lastMessageAt
                    }
                var seen = Set<UUID>()
                return mapped.filter { seen.insert($0.id).inserted }
            },
            listAtoms: { @MainActor in
                let context = ModelContext(modelContainer)
                let descriptor = FetchDescriptor<AtomEntity>(
                    sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
                )
                return try context.fetch(descriptor).map(Self.atom(from:))
            },
            loadChatMessages: { @MainActor atomID in
                let context = ModelContext(modelContainer)
                guard let entity = try Self.fetchAtom(atomID, in: context) else {
                    return []
                }
                return entity.messages
                    .sorted { $0.order < $1.order }
                    .compactMap(Self.chatMessage(from:))
            },
            saveAtom: { @MainActor atom in
                let context = ModelContext(modelContainer)
                let entity: AtomEntity
                if let existing = try Self.fetchAtom(atom.id, in: context) {
                    entity = existing
                    entity.title = atom.title
                    entity.updatedAt = atom.updatedAt
                    entity.isPinned = atom.isPinned
                    entity.groupName = atom.groupName
                } else {
                    entity = AtomEntity(
                        id: atom.id,
                        title: atom.title,
                        createdAt: atom.createdAt,
                        updatedAt: atom.updatedAt,
                        isPinned: atom.isPinned,
                        groupName: atom.groupName
                    )
                    context.insert(entity)
                }
                try context.save()
            },
            appendChatMessage: { @MainActor atomID, message in
                let context = ModelContext(modelContainer)
                guard let atom = try Self.fetchAtom(atomID, in: context) else {
                    return
                }

                if let existing = atom.messages.first(where: { $0.id == message.id }) {
                    Self.apply(message, to: existing)
                } else {
                    let nextOrder = (atom.messages.map(\.order).max() ?? -1) + 1
                    let entity = Self.entity(from: message, order: nextOrder)
                    entity.atom = atom
                    atom.messages.append(entity)
                    context.insert(entity)
                }
                atom.updatedAt = message.timestamp
                try context.save()
            },
            replaceChatMessages: { @MainActor atomID, messages in
                let context = ModelContext(modelContainer)
                guard let atom = try Self.fetchAtom(atomID, in: context) else {
                    throw PersistenceAtomHistoryError.atomNotFound(atomID)
                }

                for entity in atom.messages {
                    context.delete(entity)
                }
                atom.messages.removeAll()

                for (order, message) in messages.enumerated() {
                    let entity = Self.entity(from: message, order: order)
                    entity.atom = atom
                    atom.messages.append(entity)
                    context.insert(entity)
                }

                if let last = messages.last {
                    atom.updatedAt = last.timestamp
                }
                try context.save()
            },
            deleteAtom: { @MainActor atomID in
                let context = ModelContext(modelContainer)
                guard let entity = try Self.fetchAtom(atomID, in: context) else {
                    return
                }
                let messages = entity.messages.compactMap(Self.chatMessage(from:))
                ChatAttachmentStore.removeAll(at: ChatAttachmentStore.localPaths(in: messages))
                context.delete(entity)
                try context.save()
            },
            setPinned: { @MainActor atomID, isPinned in
                let context = ModelContext(modelContainer)
                guard let entity = try Self.fetchAtom(atomID, in: context) else {
                    return
                }
                entity.isPinned = isPinned
                try context.save()
            },
            renameAtom: { @MainActor atomID, title in
                let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                let context = ModelContext(modelContainer)
                guard let entity = try Self.fetchAtom(atomID, in: context) else {
                    return
                }
                entity.title = trimmed
                entity.updatedAt = .now
                try context.save()
            },
            setGroup: { @MainActor atomID, groupName in
                let context = ModelContext(modelContainer)
                guard let entity = try Self.fetchAtom(atomID, in: context) else {
                    return
                }
                if let groupName {
                    let trimmed = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    entity.groupName = trimmed
                } else {
                    entity.groupName = nil
                }
                try context.save()
            },
            listGroups: { @MainActor in
                let context = ModelContext(modelContainer)
                let descriptor = FetchDescriptor<AtomEntity>(
                    predicate: #Predicate { $0.groupName != nil }
                )
                let entities = try context.fetch(descriptor)
                let groups = Set(entities.compactMap(\.groupName))
                return groups.sorted()
            }
        )
    }

    @MainActor
    static func sweepExpiredVoiceAttachments(
        modelContainer: ModelContainer,
        now: Date = .now
    ) throws {
        let cutoff = ChatVoiceAttachmentRetention.expirationCutoff(from: now)
        let context = ModelContext(modelContainer)
        let atoms = try context.fetch(FetchDescriptor<AtomEntity>())

        for atom in atoms {
            let messages = atom.messages
                .sorted { $0.order < $1.order }
                .compactMap(Self.chatMessage(from:))

            let result = ChatVoiceAttachmentRetention.expireVoiceAttachments(
                in: messages,
                cutoff: cutoff
            )
            guard !result.removedPaths.isEmpty else { continue }

            ChatAttachmentStore.removeAll(at: result.removedPaths)

            for entity in atom.messages {
                context.delete(entity)
            }
            atom.messages.removeAll()

            for (order, message) in result.messages.enumerated() {
                let entity = Self.entity(from: message, order: order)
                entity.atom = atom
                atom.messages.append(entity)
                context.insert(entity)
            }
        }

        try context.save()
    }

    @MainActor
    private static func fetchAtom(
        _ id: UUID,
        in context: ModelContext
    ) throws -> AtomEntity? {
        var descriptor = FetchDescriptor<AtomEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @MainActor
    private static func atom(from entity: AtomEntity) -> Atom {
        Atom(
            id: entity.id,
            title: entity.title,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt,
            isPinned: entity.isPinned,
            groupName: entity.groupName
        )
    }

    @MainActor
    private static func listEntry(from entity: AtomEntity) -> AtomListEntry {
        let atom = atom(from: entity)
        if let last = lastListableMessage(in: entity) {
            return AtomListEntry(
                atom: atom,
                lastMessagePreview: last.preview,
                lastMessageAt: last.timestamp
            )
        }
        let fallback = atom.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return AtomListEntry(
            atom: atom,
            lastMessagePreview: fallback.isEmpty ? "New atom" : fallback,
            lastMessageAt: atom.updatedAt
        )
    }

    @MainActor
    private static func lastListableMessage(
        in entity: AtomEntity
    ) -> (preview: String, timestamp: Date)? {
        for message in entity.messages.sorted(by: { $0.order > $1.order }) {
            guard let chatMessage = chatMessage(from: message),
                  let preview = listPreview(for: chatMessage) else {
                continue
            }
            return (preview, message.timestamp)
        }
        return nil
    }

    @MainActor
    private static func listPreview(for message: ChatMessage) -> String? {
        switch message {
        case let .text(text):
            let content = text.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty { return content }
            if !text.attachments.isEmpty { return "Attachment" }
            return nil
        case let .system(system):
            let content = system.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return content.isEmpty ? nil : content
        case let .outputStream(outputStream):
            let command = outputStream.command.trimmingCharacters(in: .whitespacesAndNewlines)
            return command.isEmpty ? nil : command
        case .thinking:
            return nil
        }
    }

    @MainActor
    private static func chatMessage(from entity: AtomMessageEntity) -> ChatMessage? {
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
