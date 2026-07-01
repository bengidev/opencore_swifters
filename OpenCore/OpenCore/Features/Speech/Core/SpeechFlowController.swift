import Foundation
import Observation

/// Owns composer speech-to-text lifecycle — permissions, listening state, and voice-note delivery.
@MainActor
@Observable
final class SpeechFlowController {
    private(set) var state = SpeechFlowState()
    private let recognition: SpeechRecognitionClient
    private let autoStopThreshold: TimeInterval
    private var recognitionTask: Task<Void, Never>?
    private var durationTask: Task<Void, Never>?
    private var autoStopTriggered = false

    init(
        recognition: SpeechRecognitionClient = .preview,
        autoStopThreshold: TimeInterval = SpeechRecordingLimits.autoStopThreshold
    ) {
        self.recognition = recognition
        self.autoStopThreshold = autoStopThreshold
    }

    func clearError() {
        state.errorMessage = nil
    }

    /// Composer draft stays user-typed only; live transcript is not mirrored into the text field.
    func displayedDraft(base: String) -> String {
        base
    }

    func startListening() async {
        guard recognitionTask == nil else { return }
        clearError()

        var status = recognition.authorizationStatus()
        if status == .notDetermined {
            status = await recognition.requestAuthorization()
        }

        guard status == .authorized else {
            state.errorMessage = Self.permissionDeniedMessage
            return
        }

        state.partialTranscript = ""
        state.elapsedDuration = 0
        state.audioLevels = []
        state.isVoiceActive = false
        state.isTranscribing = false
        autoStopTriggered = false

        let stream = recognition.start()
        recognitionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                recognitionTask = nil
                stopDurationTimer()
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
            if !Task.isCancelled {
                _ = await recognition.stop()
                resetListeningPresentation()
            }
        }
    }

    func stopListening() async -> ChatMessageAttachment? {
        let waveformSamples = state.audioLevels
        let duration = state.elapsedDuration
        state.isTranscribing = true
        let result = await finishListening()
        state.isTranscribing = false
        if let attachment = Self.makeVoiceAttachment(
            from: result,
            waveformSamples: waveformSamples,
            duration: duration
        ) {
            return attachment
        }
        if result?.audioFileURL != nil,
           result?.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            state.errorMessage = "Voice note could not be transcribed. Try again or type your message."
        }
        return nil
    }

    func cancelListening() async {
        _ = await finishListening()
    }

    private func finishListening() async -> SpeechRecognitionResult? {
        recognitionTask?.cancel()
        recognitionTask = nil
        stopDurationTimer()

        let result = await recognition.stop()
        resetListeningPresentation()
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

    private func resetListeningPresentation() {
        state.isListening = false
        state.isTranscribing = false
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
            _ = await self?.stopListening()
        }
    }

    private func stopDurationTimer() {
        durationTask?.cancel()
        durationTask = nil
    }

    static func makeVoiceAttachment(
        from result: SpeechRecognitionResult?,
        waveformSamples: [Float],
        duration: TimeInterval
    ) -> ChatMessageAttachment? {
        guard let result else { return nil }
        let transcript = result.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else { return nil }
        guard let audioFileURL = result.audioFileURL,
              let storedURL = try? ChatAttachmentStore.save(
                  copyingFrom: audioFileURL,
                  suggestedFilename: "voice-note.caf"
              ) else {
            return nil
        }
        try? FileManager.default.removeItem(at: audioFileURL)

        return ChatMessageAttachment(
            kind: .audio,
            filename: "Voice note",
            localPath: storedURL.path,
            waveformSamples: waveformSamples,
            audioDuration: max(duration, result.duration),
            speechTranscript: transcript
        )
    }

    private static let permissionDeniedMessage =
        "Microphone and speech recognition access are required for voice input."
}
