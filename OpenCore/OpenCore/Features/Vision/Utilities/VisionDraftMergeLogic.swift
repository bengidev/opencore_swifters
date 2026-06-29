import Foundation

/// Pure rules for folding extracted media text into the composer draft.
nonisolated enum VisionDraftMergeLogic: Sendable {
    static func mergedDraft(existing: String, extracted: String) -> String {
        let trimmedExtracted = extracted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedExtracted.isEmpty else { return existing }

        if existing.isEmpty { return trimmedExtracted }
        if existing.hasSuffix(" ") { return existing + trimmedExtracted }
        return existing + " " + trimmedExtracted
    }
}
