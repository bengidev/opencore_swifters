import Foundation
import Testing

@testable import OpenCore

@Suite("Vision Draft Merge Logic")
struct VisionDraftMergeLogicTests {
    @Test("inserts extracted text into an empty draft")
    func emptyDraft() {
        #expect(
            VisionDraftMergeLogic.mergedDraft(existing: "", extracted: "Hello from file")
            == "Hello from file"
        )
    }

    @Test("appends extracted text with a separating space")
    func appendsWithSpace() {
        #expect(
            VisionDraftMergeLogic.mergedDraft(existing: "Draft", extracted: "more")
            == "Draft more"
        )
    }

    @Test("preserves trailing space on the existing draft")
    func preservesTrailingSpace() {
        #expect(
            VisionDraftMergeLogic.mergedDraft(existing: "Draft ", extracted: "more")
            == "Draft more"
        )
    }

    @Test("ignores blank extracted text")
    func ignoresBlankExtractedText() {
        #expect(
            VisionDraftMergeLogic.mergedDraft(existing: "Draft", extracted: "   ")
            == "Draft"
        )
    }
}
