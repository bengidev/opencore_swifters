import Foundation

/// Copies composer attachments into durable app storage.
nonisolated enum ChatAttachmentStore: Sendable {
    static func save(data: Data, suggestedFilename: String) throws -> URL {
        try ChatAttachmentSizeLimits.validateImportSize(byteCount: data.count)
        let directory = try attachmentsDirectory()
        let filename = uniqueFilename(basedOn: suggestedFilename)
        let destination = directory.appendingPathComponent(filename)
        try data.write(to: destination, options: .atomic)
        return destination
    }

    static func save(copyingFrom sourceURL: URL, suggestedFilename: String) throws -> URL {
        let data = try Data(contentsOf: sourceURL)
        return try save(data: data, suggestedFilename: suggestedFilename)
    }

    static func makeAttachmentURL(suggestedFilename: String) throws -> URL {
        let directory = try attachmentsDirectory()
        let filename = uniqueFilename(basedOn: suggestedFilename)
        return directory.appendingPathComponent(filename)
    }

    static func remove(at localPath: String) {
        try? FileManager.default.removeItem(atPath: localPath)
    }

    static func removeAll(at localPaths: [String]) {
        for path in localPaths {
            remove(at: path)
        }
    }

    static func localPaths(in messages: [ChatMessage]) -> [String] {
        messages.flatMap { message in
            switch message {
            case let .text(text):
                return text.attachments.map(\.localPath)
            case .thinking, .system, .outputStream:
                return []
            }
        }
    }

    private static func attachmentsDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base
            .appendingPathComponent("OpenCore", isDirectory: true)
            .appendingPathComponent("Attachments", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func uniqueFilename(basedOn suggestedFilename: String) -> String {
        let sanitized = (suggestedFilename as NSString).lastPathComponent
        let rawStem = (sanitized as NSString).deletingPathExtension
        let stem = rawStem.isEmpty ? "attachment" : rawStem
        let rawExt = (sanitized as NSString).pathExtension
        let suffix = UUID().uuidString.prefix(8)
        if rawExt.isEmpty {
            return "\(stem)-\(suffix)"
        }
        return "\(stem)-\(suffix).\(rawExt)"
    }
}
