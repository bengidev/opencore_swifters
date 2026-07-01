import Foundation
import Observation

/// Owns composer speech-to-text lifecycle — permissions, listening state, and transcript delivery.
@MainActor
@Observable
final class SpeechFlowController {
    private(set) var state = SpeechFlowState()
    private let recognition: SpeechRecognitionClient
    private let autoStopThreshold: TimeInterval
    private let microphoneAuthorizationStatus: @Sendable () -> SpeechAuthorizationStatus
    private let requestMicrophoneAuthorization: @Sendable () async -> SpeechAuthorizationStatus
    private var recognitionTask: Task<Void, Never>?
    private var durationTask: Task<Void, Never>?
    private var startTask: Task<Void, Never>?
    private var recognitionSessionID: UInt64 = 0
    private var autoStopTriggered = false
    /// Delivers auto-stop capture results when no caller applies `stopListening()`'s return value.
    var voiceCaptureHandler: (@MainActor (SpeechCaptureResult) -> Void)?

    init(
        recognition: SpeechRecognitionClient = .preview,
        autoStopThreshold: TimeInterval = SpeechRecordingLimits.autoStopThreshold,
        microphoneAuthorizationStatus: @escaping @Sendable () -> SpeechAuthorizationStatus = {
            SpeechMicrophoneAccess.authorizationStatus()
        },
        requestMicrophoneAuthorization: @escaping @Sendable () async -> SpeechAuthorizationStatus = {
            await SpeechMicrophoneAccess.requestAuthorization()
        }
    ) {
        self.recognition = recognition
        self.autoStopThreshold = autoStopThreshold
        self.microphoneAuthorizationStatus = microphoneAuthorizationStatus
        self.requestMicrophoneAuthorization = requestMicrophoneAuthorization
    }

    func clearError() {
        state.errorMessage = nil
    }

    /// Composer draft is user-typed while listening; transcript is applied after stop.
    func displayedDraft(base: String) -> String {
        base
    }

    func startListening() async {
        if let startTask {
            await startTask.value
            return
        }

        guard recognitionTask == nil else { return }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await performStartListening()
        }
        startTask = task
        await task.value
        startTask = nil
    }

    private func performStartListening() async {
        clearError()

        var status = recognition.authorizationStatus()
        if status == .notDetermined {
            status = await recognition.requestAuthorization()
        }

        guard status == .authorized else {
            resetListeningPresentation()
            state.errorMessage = Self.permissionDeniedMessage
            return
        }

        var microphoneStatus = microphoneAuthorizationStatus()
        if microphoneStatus == .notDetermined {
            microphoneStatus = await requestMicrophoneAuthorization()
        }

        guard microphoneStatus == .authorized else {
            resetListeningPresentation()
            state.errorMessage = Self.permissionDeniedMessage
            return
        }

        guard recognitionTask == nil else { return }

        state.partialTranscript = ""
        state.elapsedDuration = 0
        state.audioLevels = []
        state.isVoiceActive = false
        state.isTranscribing = false
        autoStopTriggered = false
        state.isListening = true

        recognitionSessionID &+= 1
        let sessionID = recognitionSessionID
        let stream = recognition.start()
        recognitionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if recognitionSessionID == sessionID {
                    recognitionTask = nil
                    stopDurationTimer()
                }
            }
            for await event in stream {
                guard !Task.isCancelled else { return }
                switch event {
                case .ready:
                    state.isListening = true
                    startDurationTimer()
                case let .partial(text), let .final(text):
                    state.partialTranscript = text
                case let .failed(message):
                    state.errorMessage = message
                    _ = await recognition.stop()
                    resetListeningPresentation()
                    return
                case let .audioLevel(level):
                    applyAudioLevel(level)
                }
            }
        }
    }

    func stopListening() async -> SpeechCaptureResult? {
        await startTask?.value

        guard state.isListening || state.isTranscribing || recognitionTask != nil else {
            return nil
        }

        let waveformSamples = state.audioLevels
        let duration = state.elapsedDuration
        let capturedPartial = state.partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        state.transcribingWaveformSamples = waveformSamples
        state.transcribingDuration = duration
        state.isTranscribing = true
        state.isListening = false

        let result = await finishListening()
        state.isTranscribing = false
        state.transcribingWaveformSamples = []
        state.transcribingDuration = 0

        let enrichedResult = Self.enrichResult(
            result,
            partialTranscript: capturedPartial,
            duration: duration
        )
        Self.discardRecordedAudio(from: enrichedResult)

        let transcript = enrichedResult?.transcript
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !transcript.isEmpty else {
            state.errorMessage = "No speech was detected. Try again or type your message."
            return nil
        }

        return SpeechCaptureResult(composerText: transcript)
    }

    func cancelListening() async {
        await startTask?.value
        _ = await finishListening()
        resetListeningPresentation()
    }

    private func finishListening() async -> SpeechRecognitionResult? {
        stopDurationTimer()
        let result = await recognition.stop()
        recognitionTask?.cancel()
        recognitionTask = nil
        resetListeningPresentation(clearTranscribing: false)
        return result
    }

    private func applyAudioLevel(_ level: Float) {
        state.isVoiceActive = SpeechRecordingDisplayLogic.isVoiceActive(level: level)
        state.audioLevels = SpeechRecordingDisplayLogic.appendWaveformSample(
            level,
            to: state.audioLevels,
            capacity: SpeechRecordingDisplayLogic.waveformSampleCapacity
        )
    }

    private func resetListeningPresentation(clearTranscribing: Bool = true) {
        state.isListening = false
        if clearTranscribing {
            state.isTranscribing = false
            state.transcribingWaveformSamples = []
            state.transcribingDuration = 0
        }
        state.partialTranscript = ""
        state.elapsedDuration = 0
        state.audioLevels = []
        state.isVoiceActive = false
        autoStopTriggered = false
    }

    private func startDurationTimer() {
        durationTask?.cancel()
        let startedAt = Date()
        durationTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, state.isListening else { return }
                state.elapsedDuration = Date().timeIntervalSince(startedAt)
                handleAutoStopIfNeeded()
            }
        }
    }

    private func handleAutoStopIfNeeded() {
        guard state.isListening,
              !autoStopTriggered,
              state.elapsedDuration >= autoStopThreshold else {
            return
        }

        autoStopTriggered = true
        Task { @MainActor [weak self] in
            guard let self, let capture = await stopListening() else { return }
            voiceCaptureHandler?(capture)
        }
    }

    static func enrichResult(
        _ result: SpeechRecognitionResult?,
        partialTranscript: String,
        duration: TimeInterval
    ) -> SpeechRecognitionResult? {
        let stoppedTranscript = result?.transcript.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !stoppedTranscript.isEmpty {
            return result
        }
        guard !partialTranscript.isEmpty else { return result }
        return SpeechRecognitionResult(
            transcript: partialTranscript,
            audioFileURL: result?.audioFileURL,
            waveformSamples: result?.waveformSamples ?? [],
            duration: result?.duration ?? duration
        )
    }

    private func stopDurationTimer() {
        durationTask?.cancel()
        durationTask = nil
    }

    static func discardRecordedAudio(from result: SpeechRecognitionResult?) {
        guard let audioFileURL = result?.audioFileURL else { return }
        try? FileManager.default.removeItem(at: audioFileURL)
    }

    private static let permissionDeniedMessage =
        "Microphone and speech recognition access are required for voice input."
}
