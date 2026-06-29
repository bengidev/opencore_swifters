import Foundation
import Testing

@testable import OpenCore

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
        let controller = SpeechFlowController(recognition: harness.makeClient())

        await controller.startListening()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(controller.state.isListening == true)
        #expect(harness.startCallCount == 1)

        await controller.cancelListening()
    }

    @Test("partial recognition updates internal transcript without changing displayed draft")
    func updatesPartialTranscript() async {
        let harness = SpeechRecognitionTestHarness()
        harness.hangsOpenAfterEvents = true
        harness.events = [.ready, .partial("hello")]
        let controller = SpeechFlowController(recognition: harness.makeClient())

        await controller.startListening()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(controller.state.partialTranscript == "hello")
        #expect(controller.displayedDraft(base: "typed text") == "typed text")

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
            )
        )

        await controller.startListening()
        for _ in 0..<100 {
            if controller.state.partialTranscript == "from background" { break }
            try? await Task.sleep(for: .milliseconds(10))
        }

        #expect(controller.state.partialTranscript == "from background")

        await controller.cancelListening()
    }

    @Test("stopping listening creates a voice attachment for the chat draft")
    func createsVoiceAttachment() async throws {
        let harness = SpeechRecognitionTestHarness()
        harness.hangsOpenAfterEvents = true
        let tempAudio = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        FileManager.default.createFile(atPath: tempAudio.path, contents: Data([0x00, 0x01]))
        defer { try? FileManager.default.removeItem(at: tempAudio) }

        harness.stopResult = SpeechRecognitionResult(
            transcript: "send this",
            audioFileURL: tempAudio,
            waveformSamples: [0.1, 0.2],
            duration: 2
        )
        harness.events = [.ready]
        let controller = SpeechFlowController(recognition: harness.makeClient())
        await controller.startListening()
        try? await Task.sleep(for: .milliseconds(50))

        let attachment = await controller.stopListening()

        #expect(attachment?.kind == .audio)
        #expect(attachment?.speechTranscript == "send this")
        #expect(controller.state.isListening == false)
        #expect(harness.stopCallCount == 1)
        if let localPath = attachment?.localPath {
            ChatAttachmentStore.remove(at: localPath)
        }
    }

    @Test("denied authorization surfaces an error instead of listening")
    func deniedAuthorizationShowsError() async {
        let harness = SpeechRecognitionTestHarness()
        harness.authorizationStatus = .denied
        let controller = SpeechFlowController(recognition: harness.makeClient())

        await controller.startListening()

        #expect(controller.state.isListening == false)
        #expect(controller.state.errorMessage != nil)
        #expect(harness.startCallCount == 0)
    }

    @Test("cancel listening discards transcript without applying")
    func cancelListeningDiscardsTranscript() async {
        let harness = SpeechRecognitionTestHarness()
        harness.hangsOpenAfterEvents = true
        harness.events = [.ready, .partial("discard me")]
        harness.stopResult = SpeechRecognitionResult(transcript: "discard me")
        let controller = SpeechFlowController(recognition: harness.makeClient())

        await controller.startListening()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(controller.state.partialTranscript == "discard me")

        await controller.cancelListening()

        #expect(controller.state.isListening == false)
        #expect(controller.state.partialTranscript.isEmpty)
        #expect(controller.state.audioLevels.isEmpty)
        #expect(controller.state.isVoiceActive == false)
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
            )
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

    @Test("recognition failure before ready keeps indicator hidden")
    func failureBeforeReadyHidesIndicator() async {
        let harness = SpeechRecognitionTestHarness()
        harness.events = [.failed("Failed to initialize recognizer")]
        let controller = SpeechFlowController(recognition: harness.makeClient())

        await controller.startListening()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(controller.state.isListening == false)
        #expect(controller.state.errorMessage != nil)
        #expect(controller.state.audioLevels.isEmpty)
        #expect(harness.stopCallCount == 1)
    }

    @Test("concurrent start requests only begin one recognition session")
    func concurrentStartOnlyBeginsOnce() async {
        let harness = SpeechRecognitionTestHarness()
        harness.hangsOpenAfterEvents = true
        harness.events = [.ready]
        let controller = SpeechFlowController(recognition: harness.makeClient())

        async let first: Void = controller.startListening()
        async let second: Void = controller.startListening()
        _ = await (first, second)
        try? await Task.sleep(for: .milliseconds(50))

        #expect(harness.startCallCount == 1)

        await controller.cancelListening()
    }

    @Test("displayedDraft leaves the composer text unchanged while listening")
    func displayedDraftLeavesComposerText() async {
        let harness = SpeechRecognitionTestHarness()
        harness.hangsOpenAfterEvents = true
        harness.events = [.ready, .partial("world")]
        let controller = SpeechFlowController(recognition: harness.makeClient())

        await controller.startListening()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(controller.displayedDraft(base: "Hello") == "Hello")

        await controller.cancelListening()
    }

    @Test("empty transcript with audio surfaces an error")
    func emptyTranscriptShowsError() async throws {
        let harness = SpeechRecognitionTestHarness()
        harness.hangsOpenAfterEvents = true
        let tempAudio = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        FileManager.default.createFile(atPath: tempAudio.path, contents: Data([0x00, 0x01]))
        defer { try? FileManager.default.removeItem(at: tempAudio) }

        harness.stopResult = SpeechRecognitionResult(
            transcript: "   ",
            audioFileURL: tempAudio,
            duration: 1
        )
        harness.events = [.ready]
        let controller = SpeechFlowController(recognition: harness.makeClient())
        await controller.startListening()
        try? await Task.sleep(for: .milliseconds(50))

        let attachment = await controller.stopListening()

        #expect(attachment == nil)
        #expect(controller.state.errorMessage != nil)
    }

    @Test("makeVoiceAttachment stores transcript behind the bubble attachment")
    func makeVoiceAttachmentUsesTranscript() throws {
        let tempAudio = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        FileManager.default.createFile(atPath: tempAudio.path, contents: Data([0x00, 0x01]))
        defer { try? FileManager.default.removeItem(at: tempAudio) }

        let attachment = SpeechFlowController.makeVoiceAttachment(
            from: SpeechRecognitionResult(
                transcript: "there",
                audioFileURL: tempAudio,
                duration: 1
            ),
            waveformSamples: [0.2],
            duration: 1
        )

        #expect(attachment?.speechTranscript == "there")
        if let localPath = attachment?.localPath {
            ChatAttachmentStore.remove(at: localPath)
        }
    }
}
