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

    /// Merges the live partial transcript into a composer draft for display while listening.
    func displayedDraft(base: String) -> String {
        guard state.isListening, !state.partialTranscript.isEmpty else { return base }
        return Self.mergedDraft(existing: base, transcript: state.partialTranscript)
    }

    func toggleListening(applyTranscript: @escaping (String) -> Void) async {
        if state.isListening {
            let transcript = await finishListening()
            guard !transcript.isEmpty else { return }
            applyTranscript(transcript)
        } else {
            await startListening()
        }
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

    func stopListening(mergingInto base: String) async -> String {
        let transcript = await finishListening()
        return Self.mergedDraft(existing: base, transcript: transcript)
    }

    func cancelListening() async {
        _ = await finishListening()
    }

    private func finishListening() async -> String {
        recognitionTask?.cancel()
        recognitionTask = nil
        stopDurationTimer()

        let final = await recognition.stop()
        let transcript = (final ?? state.partialTranscript)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        resetListeningPresentation()
        return transcript
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
