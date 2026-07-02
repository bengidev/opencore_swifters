import AVFoundation
import Foundation
import Testing

@testable import OpenCore

private func makeTestVoiceNoteCAF() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("caf")
    guard let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1) else {
        throw NSError(domain: "SpeechFlowControllerTests", code: 1)
    }
    let file = try AVAudioFile(forWriting: url, settings: format.settings)
    let frameCount: AVAudioFrameCount = 4_096
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
        throw NSError(domain: "SpeechFlowControllerTests", code: 2)
    }
    buffer.frameLength = frameCount
    if let samples = buffer.floatChannelData?[0] {
        for index in 0..<Int(frameCount) {
            samples[index] = 0.01
        }
    }
    try file.write(from: buffer)
    return url
}

private final class SpeechRecognitionTestHarness: @unchecked Sendable {
    var authorizationStatus: SpeechAuthorizationStatus = .authorized
    var requestAuthorizationResult: SpeechAuthorizationStatus?
    var events: [SpeechRecognitionEvent] = []
    var hangsOpenAfterEvents = false
    var stopResult: SpeechRecognitionResult?
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0

    func makeClient() -> SpeechRecognitionClient {
        SpeechRecognitionClient(
            authorizationStatus: { [self] in authorizationStatus },
            requestAuthorization: { [self] in
                requestAuthorizationResult ?? authorizationStatus
            },
            start: { [self] in
                startCallCount += 1
                let events = events
                let hangsOpen = hangsOpenAfterEvents
                return AsyncStream { continuation in
                    for event in events {
                        continuation.yield(event)
                    }
                    if !hangsOpen {
                        continuation.finish()
                    }
                }
            },
            stop: { [self] in
                stopCallCount += 1
                return stopResult
            }
        )
    }

    @MainActor
    func makeController(
        autoStopThreshold: TimeInterval = SpeechRecordingLimits.autoStopThreshold
    ) -> SpeechFlowController {
        SpeechFlowController(
            recognition: makeClient(),
            autoStopThreshold: autoStopThreshold,
            microphoneAuthorizationStatus: { .authorized },
            requestMicrophoneAuthorization: { .authorized }
        )
    }
}

private actor DoubleStopTracker {
    let firstResult: SpeechRecognitionResult?
    private(set) var callCount = 0

    init(firstResult: SpeechRecognitionResult?) {
        self.firstResult = firstResult
    }

    func stop() -> SpeechRecognitionResult? {
        callCount += 1
        return callCount == 1 ? firstResult : nil
    }
}

@Suite("Speech Flow Controller", .serialized)
@MainActor
struct SpeechFlowControllerTests {
    @Test("starts idle without listening or transcript")
    func startsIdle() {
        let controller = SpeechFlowController(recognition: .preview)

        #expect(controller.state.isListening == false)
        #expect(controller.state.partialTranscript.isEmpty)
        #expect(controller.state.errorMessage == nil)
    }

    @Test("toggle starts listening when authorized")
    func startsListeningWhenAuthorized() async {
        let harness = SpeechRecognitionTestHarness()
        harness.hangsOpenAfterEvents = true
        harness.events = [.ready]
        let controller = harness.makeController()

        await controller.startListening()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(controller.state.isListening == true)
        #expect(harness.startCallCount == 1)

        await controller.cancelListening()
    }

    @Test("partial recognition updates internal transcript and displayed draft while listening")
    func updatesPartialTranscript() async {
        let harness = SpeechRecognitionTestHarness()
        harness.hangsOpenAfterEvents = true
        harness.events = [.ready, .partial("hello")]
        let controller = harness.makeController()

        await controller.startListening()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(controller.state.partialTranscript == "hello")
        #expect(harness.startCallCount == 1)

        await controller.cancelListening()
    }

    @Test("background recognition events update state on main actor")
    func backgroundRecognitionEventsUpdateState() async {
        let controller = SpeechFlowController(
            recognition: SpeechRecognitionClient(
                authorizationStatus: { .authorized },
                requestAuthorization: { .authorized },
                start: {
                    AsyncStream { continuation in
                        Task.detached {
                            continuation.yield(.ready)
                            continuation.yield(.partial("from background"))
                        }
                    }
                },
                stop: { nil }
            ),
            microphoneAuthorizationStatus: { .authorized },
            requestMicrophoneAuthorization: { .authorized }
        )

        await controller.startListening()
        for _ in 0..<100 {
            if controller.state.partialTranscript == "from background" { break }
            try? await Task.sleep(for: .milliseconds(10))
        }

        #expect(controller.state.partialTranscript == "from background")

        await controller.cancelListening()
    }

    @Test("stopping listening returns transcript for the composer draft")
    func returnsTranscriptForComposer() async throws {
        let harness = SpeechRecognitionTestHarness()
        harness.hangsOpenAfterEvents = true
        let tempAudio = try makeTestVoiceNoteCAF()
        defer { try? FileManager.default.removeItem(at: tempAudio) }

        harness.stopResult = SpeechRecognitionResult(
            transcript: "send this",
            audioFileURL: tempAudio,
            waveformSamples: [0.1, 0.2],
            duration: 2
        )
        harness.events = [.ready]
        let controller = harness.makeController()
        await controller.startListening()
        try? await Task.sleep(for: .milliseconds(50))

        let capture = await controller.stopListening()

        #expect(capture?.composerText == "send this")
        #expect(capture != nil)
        #expect(controller.state.isListening == false)
        #expect(harness.stopCallCount == 1)
        #expect(FileManager.default.fileExists(atPath: tempAudio.path) == false)
    }

    @Test("denied authorization surfaces an error instead of listening")
    func deniedAuthorizationShowsError() async {
        let harness = SpeechRecognitionTestHarness()
        harness.authorizationStatus = .denied
        let controller = harness.makeController()

        await controller.startListening()

        #expect(controller.state.isListening == false)
        #expect(controller.state.errorMessage != nil)
        #expect(harness.startCallCount == 0)
    }

    @Test("cancel listening discards transcript and temporary audio")
    func cancelListeningDiscardsTranscript() async throws {
        let harness = SpeechRecognitionTestHarness()
        harness.hangsOpenAfterEvents = true
        let tempAudio = try makeTestVoiceNoteCAF()
        defer { try? FileManager.default.removeItem(at: tempAudio) }

        harness.events = [.ready, .partial("discard me")]
        harness.stopResult = SpeechRecognitionResult(
            transcript: "discard me",
            audioFileURL: tempAudio
        )
        let controller = harness.makeController()

        await controller.startListening()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(controller.state.partialTranscript == "discard me")

        await controller.cancelListening()

        #expect(controller.state.isListening == false)
        #expect(controller.state.partialTranscript.isEmpty)
        #expect(controller.state.audioLevels.isEmpty)
        #expect(controller.state.isVoiceActive == false)
        #expect(FileManager.default.fileExists(atPath: tempAudio.path) == false)
    }

    @Test("audio level events update voice activity and waveform samples")
    func audioLevelEventsUpdatePresentation() async {
        let controller = SpeechFlowController(
            recognition: SpeechRecognitionClient(
                authorizationStatus: { .authorized },
                requestAuthorization: { .authorized },
                start: {
                    AsyncStream { continuation in
                        continuation.yield(.ready)
                        continuation.yield(.audioLevel(0.001))
                        continuation.yield(.audioLevel(0.05))
                    }
                },
                stop: { nil }
            ),
            microphoneAuthorizationStatus: { .authorized },
            requestMicrophoneAuthorization: { .authorized }
        )

        await controller.startListening()
        for _ in 0..<100 {
            if controller.state.audioLevels.count >= 2 { break }
            try? await Task.sleep(for: .milliseconds(10))
        }

        #expect(controller.state.isVoiceActive == true)
        #expect(controller.state.audioLevels.count == 2)
        #expect(controller.state.audioLevels.last == 0.05)

        await controller.cancelListening()
    }

    @Test("recognition failure before ready keeps indicator hidden and discards audio")
    func failureBeforeReadyHidesIndicator() async throws {
        let harness = SpeechRecognitionTestHarness()
        let tempAudio = try makeTestVoiceNoteCAF()
        defer { try? FileManager.default.removeItem(at: tempAudio) }

        harness.events = [.failed("Failed to initialize recognizer")]
        harness.stopResult = SpeechRecognitionResult(
            transcript: "",
            audioFileURL: tempAudio
        )
        let controller = harness.makeController()

        await controller.startListening()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(controller.state.isListening == false)
        #expect(controller.state.errorMessage != nil)
        #expect(controller.state.audioLevels.isEmpty)
        #expect(harness.stopCallCount == 1)
        #expect(FileManager.default.fileExists(atPath: tempAudio.path) == false)
    }

    @Test("concurrent start requests only begin one recognition session")
    func concurrentStartOnlyBeginsOnce() async {
        let harness = SpeechRecognitionTestHarness()
        harness.hangsOpenAfterEvents = true
        harness.events = [.ready]
        let controller = harness.makeController()

        async let first: Void = controller.startListening()
        async let second: Void = controller.startListening()
        _ = await (first, second)
        try? await Task.sleep(for: .milliseconds(50))

        #expect(harness.startCallCount == 1)

        await controller.cancelListening()
    }

    @Test("start listening shows waveform immediately before recognition is ready")
    func showsWaveformBeforeReady() async {
        let harness = SpeechRecognitionTestHarness()
        harness.hangsOpenAfterEvents = true
        harness.events = []
        let controller = harness.makeController()

        let listenTask = Task { await controller.startListening() }
        try? await Task.sleep(for: .milliseconds(50))

        #expect(controller.state.isListening == true)

        await controller.cancelListening()
        await listenTask.value
    }

    @Test("empty transcript surfaces an error and discards recorded audio")
    func emptyTranscriptShowsError() async throws {
        let harness = SpeechRecognitionTestHarness()
        harness.hangsOpenAfterEvents = true
        let tempAudio = try makeTestVoiceNoteCAF()
        defer { try? FileManager.default.removeItem(at: tempAudio) }

        harness.stopResult = SpeechRecognitionResult(
            transcript: "   ",
            audioFileURL: tempAudio,
            duration: 1
        )
        harness.events = [.ready]
        let controller = harness.makeController()
        await controller.startListening()
        try? await Task.sleep(for: .milliseconds(50))

        let capture = await controller.stopListening()

        #expect(capture == nil)
        #expect(controller.state.errorMessage != nil)
        #expect(FileManager.default.fileExists(atPath: tempAudio.path) == false)
    }

    @Test("finishListening preserves stop result when stream termination also stops")
    func finishListeningPreservesStopResultOnDoubleStop() async throws {
        let tempAudio = try makeTestVoiceNoteCAF()
        defer { try? FileManager.default.removeItem(at: tempAudio) }

        let expectedResult = SpeechRecognitionResult(
            transcript: "hello",
            audioFileURL: tempAudio,
            duration: 1
        )
        let stopTracker = DoubleStopTracker(firstResult: expectedResult)
        let controller = SpeechFlowController(
            recognition: SpeechRecognitionClient(
                authorizationStatus: { .authorized },
                requestAuthorization: { .authorized },
                start: {
                    AsyncStream { continuation in
                        continuation.yield(.ready)
                        continuation.onTermination = { _ in
                            Task {
                                _ = await stopTracker.stop()
                            }
                        }
                    }
                },
                stop: {
                    await stopTracker.stop()
                }
            ),
            microphoneAuthorizationStatus: { .authorized },
            requestMicrophoneAuthorization: { .authorized }
        )

        await controller.startListening()
        try? await Task.sleep(for: .milliseconds(50))

        let capture = await controller.stopListening()

        #expect(capture?.composerText == "hello")
        #expect(await stopTracker.callCount >= 1)
        #expect(FileManager.default.fileExists(atPath: tempAudio.path) == false)
    }

    @Test("discardRecordedAudio removes temporary recording file")
    func discardRecordedAudioRemovesFile() throws {
        let tempAudio = try makeTestVoiceNoteCAF()
        defer { try? FileManager.default.removeItem(at: tempAudio) }

        SpeechFlowController.discardRecordedAudio(
            from: SpeechRecognitionResult(
                transcript: "hello",
                audioFileURL: tempAudio,
                duration: 1
            )
        )

        #expect(FileManager.default.fileExists(atPath: tempAudio.path) == false)
    }

    @Test("stop falls back to streamed partial when recognition stop returns empty transcript")
    func stopFallsBackToStreamedPartial() async throws {
        let harness = SpeechRecognitionTestHarness()
        harness.hangsOpenAfterEvents = true
        let tempAudio = try makeTestVoiceNoteCAF()
        defer { try? FileManager.default.removeItem(at: tempAudio) }

        harness.stopResult = SpeechRecognitionResult(
            transcript: "",
            audioFileURL: tempAudio,
            duration: 1
        )
        harness.events = [.ready, .partial("heard this")]
        let controller = harness.makeController()
        await controller.startListening()
        try? await Task.sleep(for: .milliseconds(50))

        let capture = await controller.stopListening()

        #expect(capture?.composerText == "heard this")
        #expect(FileManager.default.fileExists(atPath: tempAudio.path) == false)
    }

    @Test("auto-stops recording when max duration is reached")
    func autoStopsAtMaxDuration() async throws {
        let harness = SpeechRecognitionTestHarness()
        harness.hangsOpenAfterEvents = true
        let tempAudio = try makeTestVoiceNoteCAF()
        defer { try? FileManager.default.removeItem(at: tempAudio) }

        harness.stopResult = SpeechRecognitionResult(
            transcript: "auto stopped",
            audioFileURL: tempAudio,
            duration: SpeechRecordingLimits.maxDurationSeconds
        )
        harness.events = [.ready]
        let controller = harness.makeController(autoStopThreshold: 0.05)
        await controller.startListening()

        for _ in 0..<100 {
            if harness.stopCallCount > 0 { break }
            try? await Task.sleep(for: .milliseconds(20))
        }

        #expect(harness.stopCallCount == 1)
        #expect(controller.state.isListening == false)
    }

    @Test("final recognition event keeps listening open until explicit stop")
    func finalEventKeepsListeningOpenUntilStop() async throws {
        let harness = SpeechRecognitionTestHarness()
        harness.hangsOpenAfterEvents = true
        let tempAudio = try makeTestVoiceNoteCAF()
        defer { try? FileManager.default.removeItem(at: tempAudio) }

        harness.stopResult = SpeechRecognitionResult(
            transcript: "hello there",
            audioFileURL: tempAudio,
            duration: 2
        )
        harness.events = [.ready, .final("hello there")]
        let controller = harness.makeController()
        await controller.startListening()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(controller.state.isListening == true)

        let capture = await controller.stopListening()

        #expect(capture?.composerText == "hello there")
        #expect(FileManager.default.fileExists(atPath: tempAudio.path) == false)
    }

    @Test("stop without an active session does not surface a no-speech error")
    func stopWithoutActiveSessionIsNoOp() async {
        let controller = SpeechFlowController(recognition: .preview)

        let capture = await controller.stopListening()

        #expect(capture == nil)
        #expect(controller.state.errorMessage == nil)
    }

    @Test("second consecutive capture returns transcript")
    func secondConsecutiveCaptureReturnsTranscript() async throws {
        let harness = SpeechRecognitionTestHarness()
        harness.hangsOpenAfterEvents = true
        let tempAudio = try makeTestVoiceNoteCAF()
        defer { try? FileManager.default.removeItem(at: tempAudio) }

        harness.stopResult = SpeechRecognitionResult(
            transcript: "first take",
            audioFileURL: tempAudio,
            waveformSamples: [0.1],
            duration: 1
        )
        harness.events = [.ready, .partial("first take")]
        let controller = harness.makeController()

        await controller.startListening()
        try? await Task.sleep(for: .milliseconds(50))
        let firstCapture = await controller.stopListening()

        #expect(firstCapture?.composerText == "first take")
        #expect(harness.stopCallCount == 1)
        #expect(controller.state.isListening == false)
        #expect(controller.state.errorMessage == nil)

        harness.stopResult = SpeechRecognitionResult(
            transcript: "second take",
            audioFileURL: tempAudio,
            waveformSamples: [0.2],
            duration: 2
        )
        harness.events = [.ready, .partial("second take")]

        await controller.startListening()
        try? await Task.sleep(for: .milliseconds(50))
        let secondCapture = await controller.stopListening()

        #expect(secondCapture?.composerText == "second take")
        #expect(harness.startCallCount == 2)
        #expect(harness.stopCallCount == 2)
        #expect(controller.state.errorMessage == nil)
    }

    @Test("stopListening publishes pendingCapture for composer consumption")
    func stopPublishesPendingCapture() async throws {
        let harness = SpeechRecognitionTestHarness()
        harness.hangsOpenAfterEvents = true
        let tempAudio = try makeTestVoiceNoteCAF()
        defer { try? FileManager.default.removeItem(at: tempAudio) }

        harness.stopResult = SpeechRecognitionResult(
            transcript: "hello again",
            audioFileURL: tempAudio,
            duration: 1
        )
        harness.events = [.ready, .partial("hello again")]
        let controller = harness.makeController()

        await controller.startListening()
        try? await Task.sleep(for: .milliseconds(50))

        let capture = await controller.stopListening()

        #expect(capture?.composerText == "hello again")
        #expect(controller.state.pendingCapture?.composerText == "hello again")
    }

    @Test("remote transcription failure surfaces a distinct error")
    func remoteTranscriptionFailureShowsDistinctError() async throws {
        let harness = SpeechRecognitionTestHarness()
        harness.hangsOpenAfterEvents = true
        let tempAudio = try makeTestVoiceNoteCAF()
        defer { try? FileManager.default.removeItem(at: tempAudio) }

        harness.stopResult = SpeechRecognitionResult(
            transcript: "",
            audioFileURL: tempAudio,
            duration: 1,
            failureMessage: "Voice transcription failed. Check your API key in Settings."
        )
        harness.events = [.ready]
        let controller = harness.makeController()
        await controller.startListening()
        try? await Task.sleep(for: .milliseconds(50))

        let capture = await controller.stopListening()

        #expect(capture == nil)
        #expect(controller.state.errorMessage == "Voice transcription failed. Check your API key in Settings.")
        #expect(controller.state.pendingCapture == nil)
    }

    @Test("remote transcription failure preserves partial transcript in composer")
    func remoteTranscriptionFailurePreservesPartialTranscript() async throws {
        let harness = SpeechRecognitionTestHarness()
        harness.hangsOpenAfterEvents = true
        let tempAudio = try makeTestVoiceNoteCAF()
        defer { try? FileManager.default.removeItem(at: tempAudio) }

        harness.stopResult = SpeechRecognitionResult(
            transcript: "",
            audioFileURL: tempAudio,
            duration: 1,
            failureMessage: "Voice transcription failed. Check your API key in Settings."
        )
        harness.events = [.ready, .partial("partial take")]
        let controller = harness.makeController()
        await controller.startListening()
        try? await Task.sleep(for: .milliseconds(50))

        let capture = await controller.stopListening()

        #expect(capture?.composerText == "partial take")
        #expect(controller.state.pendingCapture?.composerText == "partial take")
        #expect(controller.state.errorMessage == nil)
    }

    @Test("concurrent stopListening calls only complete once")
    func concurrentStopOnlyCompletesOnce() async throws {
        let harness = SpeechRecognitionTestHarness()
        harness.hangsOpenAfterEvents = true
        let tempAudio = try makeTestVoiceNoteCAF()
        defer { try? FileManager.default.removeItem(at: tempAudio) }

        harness.stopResult = SpeechRecognitionResult(
            transcript: "once only",
            audioFileURL: tempAudio,
            duration: 1
        )
        harness.events = [.ready]
        let controller = harness.makeController()
        await controller.startListening()
        try? await Task.sleep(for: .milliseconds(50))

        async let first = controller.stopListening()
        async let second = controller.stopListening()
        let results = await [first, second]

        #expect(results.compactMap { $0 }.count == 1)
        #expect(harness.stopCallCount == 1)
    }
}
