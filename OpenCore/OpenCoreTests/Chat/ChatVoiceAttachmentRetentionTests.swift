import Foundation
import Testing

@testable import OpenCore

@Suite("Chat Voice Attachment Retention")
struct ChatVoiceAttachmentRetentionTests {
    @Test("expires audio attachments older than one week")
    func expiresOldVoiceAttachments() throws {
        let cutoff = Date(timeIntervalSince1970: 1_000_000)
        let oldTimestamp = cutoff.addingTimeInterval(-60)
        let message = ChatTextMessage(
            id: UUID(),
            role: .user,
            content: "",
            isComplete: true,
            timestamp: oldTimestamp,
            attachments: [
                ChatMessageAttachment(
                    kind: .audio,
                    filename: "Voice note",
                    localPath: "/tmp/voice.caf",
                    speechTranscript: "Expired note"
                )
            ]
        )

        let (updated, removedPaths) = ChatVoiceAttachmentRetention.expireVoiceAttachments(
            in: message,
            cutoff: cutoff
        )

        #expect(updated.attachments.isEmpty)
        #expect(updated.content == "Expired note")
        #expect(removedPaths == ["/tmp/voice.caf"])
    }

    @Test("keeps recent voice attachments")
    func keepsRecentVoiceAttachments() throws {
        let cutoff = Date(timeIntervalSince1970: 1_000_000)
        let recentTimestamp = cutoff.addingTimeInterval(60)
        let message = ChatTextMessage(
            id: UUID(),
            role: .user,
            content: "",
            isComplete: true,
            timestamp: recentTimestamp,
            attachments: [
                ChatMessageAttachment(
                    kind: .audio,
                    filename: "Voice note",
                    localPath: "/tmp/voice.caf",
                    speechTranscript: "Fresh note"
                )
            ]
        )

        let (updated, removedPaths) = ChatVoiceAttachmentRetention.expireVoiceAttachments(
            in: message,
            cutoff: cutoff
        )

        #expect(updated.attachments.count == 1)
        #expect(updated.content.isEmpty)
        #expect(removedPaths.isEmpty)
    }

    @Test("keeps imported audio attachments without speech transcripts")
    func keepsImportedAudioWithoutSpeechTranscript() throws {
        let cutoff = Date(timeIntervalSince1970: 1_000_000)
        let oldTimestamp = cutoff.addingTimeInterval(-60)
        let message = ChatTextMessage(
            id: UUID(),
            role: .user,
            content: "Imported clip",
            isComplete: true,
            timestamp: oldTimestamp,
            attachments: [
                ChatMessageAttachment(
                    kind: .audio,
                    filename: "sample.mp3",
                    localPath: "/tmp/sample.mp3"
                )
            ]
        )

        let (updated, removedPaths) = ChatVoiceAttachmentRetention.expireVoiceAttachments(
            in: message,
            cutoff: cutoff
        )

        #expect(updated.attachments.count == 1)
        #expect(updated.content == "Imported clip")
        #expect(removedPaths.isEmpty)
    }
}
