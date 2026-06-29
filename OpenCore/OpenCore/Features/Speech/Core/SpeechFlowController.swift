import Foundation
import Observation

/// Owns composer speech-to-text lifecycle — permissions, listening state, and transcript delivery.
@MainActor
@Observable
final class SpeechFlowController {
    private(set) var state = SpeechFlowState()
    private let recognition: SpeechRecognitionClient
    private var recognitionTask: Task<Void, Never>?
    private var durationTask: Task<Void, Never>?

    init(recognition: SpeechRecognitionClient = .preview) {
        self.recognition = recognition
    }

    func clearError() {
        state.errorMessage = nil
    }

    func toggleListening(applyTranscript: @escaping (String) -> Void) async {
        if state.isListening {
            await stopListening(applyTranscript: applyTranscript)
        } else {
            await startListening()
        }
    }

    func stopListening(applyTranscript: @escaping (String) -> Void) async {
        await finishListening(applyTranscript: applyTranscript)
    }

    func cancelListening() async {
        await finishListening(applyTranscript: nil)
    }

    private func finishListening(applyTranscript: ((String) -> Void)?) async {
        recognitionTask?.cancel()
        recognitionTask = nil
        stopDurationTimer()

        let final = await recognition.stop()
        let transcript = (final ?? state.partialTranscript)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        resetListeningPresentation()

        guard let applyTranscript, !transcript.isEmpty else { return }
        applyTranscript(transcript)
    }

    private func startListening() async {
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

        let stream = recognition.start()
        recognitionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                stopDurationTimer()
                if state.isListening {
                    resetListeningPresentation()
                }
            }
            for await event in stream {
                guard !Task.isCancelled else { return }
                switch event {
                case .ready:
                    state.isListening = true
                    startDurationTimer()
                case let .partial(text):
                    state.partialTranscript = text
                case let .final(text):
                    state.partialTranscript = text
                case let .failed(message):
                    state.errorMessage = message
                    resetListeningPresentation()
                case let .audioLevel(level):
                    applyAudioLevel(level)
                }
            }
        }
    }

    private func applyAudioLevel(_ level: Float) {
        state.isVoiceActive = SpeechRecordingDisplayLogic.isVoiceActive(level: level)

        var levels = state.audioLevels
        levels.append(level)
        let capacity = SpeechRecordingDisplayLogic.waveformSampleCapacity
        if levels.count > capacity {
            levels.removeFirst(levels.count - capacity)
        }
        state.audioLevels = levels
    }

    private func resetListeningPresentation() {
        state.isListening = false
        state.partialTranscript = ""
        state.elapsedDuration = 0
        state.audioLevels = []
        state.isVoiceActive = false
    }

    private func startDurationTimer() {
        durationTask?.cancel()
        let startedAt = Date()
        durationTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, state.isListening else { return }
                state.elapsedDuration = Date().timeIntervalSince(startedAt)
            }
        }
    }

    private func stopDurationTimer() {
        durationTask?.cancel()
        durationTask = nil
    }

    static func mergedDraft(existing: String, transcript: String) -> String {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else { return existing }

        if existing.isEmpty { return trimmedTranscript }
        if existing.hasSuffix(" ") { return existing + trimmedTranscript }
        return existing + " " + trimmedTranscript
    }

    private static let permissionDeniedMessage =
        "Microphone and speech recognition access are required for voice input."
}
