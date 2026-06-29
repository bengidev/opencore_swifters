import Foundation
import Testing

@testable import OpenCore

@Suite("Speech Recording Display Logic")
struct SpeechRecordingDisplayLogicTests {
    @Test("formats elapsed duration as minutes and zero-padded seconds")
    func formatsElapsedDuration() {
        #expect(SpeechRecordingDisplayLogic.formatElapsedDuration(0) == "0:00")
        #expect(SpeechRecordingDisplayLogic.formatElapsedDuration(9) == "0:09")
        #expect(SpeechRecordingDisplayLogic.formatElapsedDuration(59) == "0:59")
        #expect(SpeechRecordingDisplayLogic.formatElapsedDuration(60) == "1:00")
        #expect(SpeechRecordingDisplayLogic.formatElapsedDuration(125) == "2:05")
    }

    @Test("detects voice activity above RMS threshold")
    func voiceActivityThreshold() {
        let threshold = SpeechRecordingDisplayLogic.defaultVoiceActivityThreshold

        #expect(SpeechRecordingDisplayLogic.isVoiceActive(level: 0, threshold: threshold) == false)
        #expect(SpeechRecordingDisplayLogic.isVoiceActive(level: threshold, threshold: threshold) == false)
        #expect(SpeechRecordingDisplayLogic.isVoiceActive(level: threshold + 0.001, threshold: threshold) == true)
        #expect(SpeechRecordingDisplayLogic.isVoiceActive(level: 0.2, threshold: threshold) == true)
    }

    @Test("waveform bars stay idle when levels are below threshold")
    func idleWaveformBars() {
        let heights = SpeechRecordingDisplayLogic.waveformBarHeights(
            levels: [0.001, 0.002, 0.003],
            barCount: 4
        )

        #expect(heights.count == 4)
        #expect(heights.allSatisfy { $0 == 0.12 })
    }

    @Test("waveform bars scale with voice-active levels")
    func activeWaveformBars() {
        let heights = SpeechRecordingDisplayLogic.waveformBarHeights(
            levels: [0.05, 0.1, 0.2],
            barCount: 3
        )

        #expect(heights.count == 3)
        #expect(heights[0] > 0.12)
        #expect(heights[1] > heights[0])
        #expect(heights[2] > heights[1])
    }

    @Test("appends waveform samples with ring-buffer capacity")
    func appendWaveformSample() {
        let capacity = 3
        let first = SpeechRecordingDisplayLogic.appendWaveformSample(0.1, to: [], capacity: capacity)
        let second = SpeechRecordingDisplayLogic.appendWaveformSample(0.2, to: first, capacity: capacity)
        let third = SpeechRecordingDisplayLogic.appendWaveformSample(0.3, to: second, capacity: capacity)
        let fourth = SpeechRecordingDisplayLogic.appendWaveformSample(0.4, to: third, capacity: capacity)

        #expect(fourth == [0.2, 0.3, 0.4])
    }
}

@Suite("Speech Recognizer Locale Resolver")
struct SpeechRecognizerLocaleResolverTests {
    @Test("prefers the device locale when supported")
    func prefersDeviceLocale() {
        let preferred = Locale(identifier: "fr-FR")

        let resolved = SpeechRecognizerLocaleResolver.resolve(preferred: preferred) { locale in
            locale.identifier.hasPrefix("fr")
        }

        #expect(resolved == preferred)
    }

    @Test("falls back to language-only locale when region is unsupported")
    func fallsBackToLanguageOnly() {
        let preferred = Locale(identifier: "fr-CA")

        let resolved = SpeechRecognizerLocaleResolver.resolve(preferred: preferred) { locale in
            locale.identifier == "fr"
        }

        #expect(resolved?.identifier == "fr")
    }

    @Test("uses English when available and nothing else matches")
    func usesEnglishWhenAvailable() {
        let resolved = SpeechRecognizerLocaleResolver.resolve(
            preferred: Locale(identifier: "xx-YY")
        ) { locale in
            locale.identifier == "en-US"
        }

        #expect(resolved == Locale(identifier: "en-US"))
    }

    @Test("returns nil when no locale is available")
    func returnsNilWhenNoLocaleAvailable() {
        let resolved = SpeechRecognizerLocaleResolver.resolve(
            preferred: Locale(identifier: "xx-YY")
        ) { _ in false }

        #expect(resolved == nil)
    }
}
