import Foundation
import Testing

@testable import OpenCore

private final class SpeechRecognitionTestHarness: @unchecked Sendable {
    var authorizationStatus: SpeechAuthorizationStatus = .authorized
    var requestAuthorizationResult: SpeechAuthorizationStatus?
    var events: [SpeechRecognitionEvent] = []
    var hangsOpenAfterEvents = false
    var stopResult: String?
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

        await controller.toggleListening { _ in }
        try? await Task.sleep(for: .milliseconds(50))

        #expect(controller.state.isListening == true)
        #expect(harness.startCallCount == 1)

        await controller.cancelListening()
    }

    @Test("partial recognition updates visible transcript")
    func updatesPartialTranscript() async {
        let harness = SpeechRecognitionTestHarness()
        harness.hangsOpenAfterEvents = true
        harness.events = [.ready, .partial("hello")]
        let controller = SpeechFlowController(recognition: harness.makeClient())

        await controller.toggleListening { _ in }
        try? await Task.sleep(for: .milliseconds(50))

        #expect(controller.state.partialTranscript == "hello")

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

        await controller.toggleListening { _ in }
        for _ in 0..<100 {
            if controller.state.partialTranscript == "from background" { break }
            try? await Task.sleep(for: .milliseconds(10))
        }

        #expect(controller.state.partialTranscript == "from background")

        await controller.cancelListening()
    }

    @Test("stopping listening applies final transcript to draft")
    func appliesFinalTranscript() async {
        let harness = SpeechRecognitionTestHarness()
        harness.hangsOpenAfterEvents = true
        harness.stopResult = "send this"
        harness.events = [.ready]
        let controller = SpeechFlowController(recognition: harness.makeClient())
        await controller.toggleListening { _ in }
        try? await Task.sleep(for: .milliseconds(50))

        var applied = ""
        await controller.toggleListening { applied = $0 }

        #expect(applied == "send this")
        #expect(controller.state.isListening == false)
        #expect(harness.stopCallCount == 1)
    }

    @Test("denied authorization surfaces an error instead of listening")
    func deniedAuthorizationShowsError() async {
        let harness = SpeechRecognitionTestHarness()
        harness.authorizationStatus = .denied
        let controller = SpeechFlowController(recognition: harness.makeClient())

        await controller.toggleListening { _ in }

        #expect(controller.state.isListening == false)
        #expect(controller.state.errorMessage != nil)
        #expect(harness.startCallCount == 0)
    }

    @Test("cancel listening discards transcript without applying")
    func cancelListeningDiscardsTranscript() async {
        let harness = SpeechRecognitionTestHarness()
        harness.hangsOpenAfterEvents = true
        harness.events = [.ready, .partial("discard me")]
        harness.stopResult = "discard me"
        let controller = SpeechFlowController(recognition: harness.makeClient())

        await controller.toggleListening { _ in }
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

        await controller.toggleListening { _ in }
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

        await controller.toggleListening { _ in }
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

    @Test("displayedDraft merges partial transcript into base draft")
    func displayedDraftMergesPartialTranscript() async {
        let harness = SpeechRecognitionTestHarness()
        harness.hangsOpenAfterEvents = true
        harness.events = [.ready, .partial("world")]
        let controller = SpeechFlowController(recognition: harness.makeClient())

        await controller.startListening()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(controller.displayedDraft(base: "Hello") == "Hello world")

        await controller.cancelListening()
    }

    @Test("stopListening returns merged draft without mutating speech state")
    func stopListeningReturnsMergedDraft() async {
        let harness = SpeechRecognitionTestHarness()
        harness.hangsOpenAfterEvents = true
        harness.stopResult = "there"
        harness.events = [.ready]
        let controller = SpeechFlowController(recognition: harness.makeClient())

        await controller.startListening()
        try? await Task.sleep(for: .milliseconds(50))

        let merged = await controller.stopListening(mergingInto: "Hi")

        #expect(merged == "Hi there")
        #expect(controller.state.isListening == false)
    }

    @Test("mergedDraft inserts spacing between existing text and transcript")
    func mergedDraftSpacing() {
        #expect(SpeechFlowController.mergedDraft(existing: "Hi", transcript: "there") == "Hi there")
        #expect(SpeechFlowController.mergedDraft(existing: "Hi ", transcript: "there") == "Hi there")
        #expect(SpeechFlowController.mergedDraft(existing: "", transcript: "there") == "there")
    }
}
