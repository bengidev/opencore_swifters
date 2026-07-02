import Foundation
import Testing

@testable import OpenCore

@Suite("Speech Recording Limits")
struct SpeechRecordingLimitsTests {
    @Test("max duration matches remodex-style 120 second cap")
    func maxDurationIsTwoMinutes() {
        #expect(SpeechRecordingLimits.maxDurationSeconds == 120)
    }

    @Test("auto-stop triggers just before the hard limit")
    func autoStopThreshold() {
        #expect(SpeechRecordingLimits.shouldAutoStop(elapsed: 119.7) == false)
        #expect(SpeechRecordingLimits.shouldAutoStop(elapsed: 119.75) == true)
        #expect(SpeechRecordingLimits.shouldAutoStop(elapsed: 120) == true)
    }
}
