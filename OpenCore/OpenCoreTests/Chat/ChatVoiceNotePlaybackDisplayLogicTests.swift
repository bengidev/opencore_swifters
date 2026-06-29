import Foundation
import Testing

@testable import OpenCore

@Suite("Chat Voice Note Playback Display Logic")
struct ChatVoiceNotePlaybackDisplayLogicTests {
    @Test("computes playback progress from current time and duration")
    func playbackProgress() {
        #expect(ChatVoiceNotePlaybackDisplayLogic.playbackProgress(currentTime: 0, duration: 10) == 0)
        #expect(ChatVoiceNotePlaybackDisplayLogic.playbackProgress(currentTime: 5, duration: 10) == 0.5)
        #expect(ChatVoiceNotePlaybackDisplayLogic.playbackProgress(currentTime: 10, duration: 10) == 1)
        #expect(ChatVoiceNotePlaybackDisplayLogic.playbackProgress(currentTime: 12, duration: 10) == 1)
        #expect(ChatVoiceNotePlaybackDisplayLogic.playbackProgress(currentTime: 3, duration: 0) == 0)
    }

    @Test("shows elapsed time while playback is active")
    func displayedDuration() {
        #expect(
            ChatVoiceNotePlaybackDisplayLogic.displayedDuration(
                currentTime: 4,
                totalDuration: 12,
                isPlaybackActive: true
            ) == 4
        )
        #expect(
            ChatVoiceNotePlaybackDisplayLogic.displayedDuration(
                currentTime: 4,
                totalDuration: 12,
                isPlaybackActive: false
            ) == 12
        )
    }

    @Test("marks waveform bars as played up to the current progress")
    func playedBars() {
        #expect(
            ChatVoiceNotePlaybackDisplayLogic.isBarPlayed(
                barIndex: 0,
                barCount: 4,
                progress: 0.25
            )
        )
        #expect(
            ChatVoiceNotePlaybackDisplayLogic.isBarPlayed(
                barIndex: 1,
                barCount: 4,
                progress: 0.25
            ) == false
        )
        #expect(
            ChatVoiceNotePlaybackDisplayLogic.isBarPlayed(
                barIndex: 3,
                barCount: 4,
                progress: 1
            )
        )
    }
}
