import Foundation
import AVFoundation

/// Remote speech recognition via an OpenAI-compatible Whisper transcription API.
///
/// Records audio locally to a file while streaming audio levels for the
/// waveform indicator. On `stop()`, the recorded audio is posted to the
/// `/v1/audio/transcriptions` endpoint and the returned transcript is
/// packaged into `SpeechRecognitionResult`.
///
/// The API endpoint and credentials are resolved lazily per request so a
/// credential change takes effect on the next recording session.
nonisolated final class RemoteSpeechRecognitionStrategy: SpeechRecognitionStrategy {
    let identifier = "remote"

    private let credentialStore: CredentialStoring
    private let credentialProviderID: String
    private let apiBaseURL: URL
    private let model: String
    private let urlSession: URLSession
    private let audioQueue: DispatchQueue

    /// - Parameters:
    ///   - credentialStore: Resolves the API key at transcription time.
    ///   - credentialProviderID: Provider ID used to look up the API key
    ///     in the credential store. Defaults to `"openai"` matching the
    ///     project's provider ID convention.
    ///   - apiBaseURL: Base URL for the OpenAI-compatible API
    ///     (e.g. `https://api.openai.com/v1`).
    ///   - model: Whisper model identifier (default `whisper-1`).
    ///   - urlSession: URL session for API calls (default `.shared`).
    init(
        credentialStore: CredentialStoring,
        credentialProviderID: String = "openai",
        apiBaseURL: URL = URL(string: "https://api.openai.com/v1")!,
        model: String = "whisper-1",
        urlSession: URLSession = .shared
    ) {
        self.credentialStore = credentialStore
        self.credentialProviderID = credentialProviderID
        self.apiBaseURL = apiBaseURL
        self.model = model
        self.urlSession = urlSession
        self.audioQueue = DispatchQueue(
            label: "io.github.bengidev.OpenCore.speech.remote",
            qos: .userInitiated
        )
    }

    // MARK: - Authorization

    /// Returns `.denied` when no API credential is available so
    /// `SpeechFlowController` can surface a meaningful error rather than
    /// silently recording audio that will fail to transcribe.
    nonisolated func authorizationStatus() -> SpeechAuthorizationStatus {
        credentialStore.secret(for: credentialProviderID) != nil ? .authorized : .denied
    }

    nonisolated func requestAuthorization() async -> SpeechAuthorizationStatus {
        credentialStore.secret(for: credentialProviderID) != nil ? .authorized : .denied
    }

    // MARK: - Recognition

    nonisolated func start() -> AsyncStream<SpeechRecognitionEvent> {
        AsyncStream { continuation in
            audioQueue.async {
                do {
                    try self.beginRecording(continuation: continuation)
                } catch {
                    continuation.yield(.failed(error.localizedDescription))
                    continuation.finish()
                }
            }
        }
    }

    nonisolated func stop() async -> SpeechRecognitionResult? {
        var capturedState: RecordingState?
        audioQueue.sync {
            capturedState = self.state
            self.state = nil
        }
        guard let state = capturedState else { return nil }

        let result = await finishRecording(state: state)
        audioQueue.async {
            self.tearDownRecording(state: state)
        }
        return result
    }

    /// Transcribe an externally captured audio file through the Whisper API.
    ///
    /// Used by `FallbackSpeechRecognitionStrategy` to transcribe audio
    /// already recorded by the on-device strategy.
    nonisolated func transcribe(
        audioFileURL: URL,
        waveformSamples: [Float],
        duration: TimeInterval
    ) async -> SpeechRecognitionResult? {
        guard let apiKey = credentialStore.secret(for: credentialProviderID) else { return nil }
        let transcript = await transcribeAudio(fileURL: audioFileURL, apiKey: apiKey)
        return SpeechRecognitionResult(
            transcript: transcript,
            audioFileURL: audioFileURL,
            waveformSamples: waveformSamples,
            duration: duration
        )
    }

    // MARK: - Recording State

    private final class RecordingState: @unchecked Sendable {
        var audioEngine: AVAudioEngine?
        var audioFile: AVAudioFile?
        var recordingURL: URL?
        var waveformSamples: [Float] = []
        var recordingStartedAt: Date?
        var continuation: AsyncStream<SpeechRecognitionEvent>.Continuation?
    }

    private nonisolated(unsafe) var state: RecordingState?

    // MARK: - Audio Capture

    private func beginRecording(
        continuation: AsyncStream<SpeechRecognitionEvent>.Continuation
    ) throws {
        let recordingState = RecordingState()
        self.state = recordingState
        recordingState.continuation = continuation

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let recordingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        recordingState.recordingURL = recordingURL
        recordingState.recordingStartedAt = Date()

        let engine = AVAudioEngine()
        recordingState.audioEngine = engine

        let inputNode = engine.inputNode
        let tapFormat = self.recordingTapFormat(for: inputNode)
        guard let tapFormat else {
            throw SpeechSystemRecognitionError.audioFormatUnavailable
        }

        let audioFile = try AVAudioFile(forWriting: recordingURL, settings: tapFormat.settings)
        recordingState.audioFile = audioFile

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: tapFormat) { [weak self] buffer, _ in
            guard let self else { return }
            try? audioFile.write(from: buffer)
            let level = Self.rmsLevel(from: buffer)
            self.audioQueue.async {
                recordingState.waveformSamples.append(level)
                continuation.yield(.audioLevel(level))
            }
        }

        engine.prepare()
        try engine.start()

        continuation.yield(.ready)
    }

    private func finishRecording(state: RecordingState) async -> SpeechRecognitionResult? {
        let duration = state.recordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        let waveformSamples = state.waveformSamples
        guard let recordingURL = state.recordingURL else { return nil }

        guard let apiKey = credentialStore.secret(for: credentialProviderID) else {
            return SpeechRecognitionResult(
                transcript: "",
                audioFileURL: recordingURL,
                waveformSamples: waveformSamples,
                duration: duration
            )
        }

        let transcript = await transcribeAudio(fileURL: recordingURL, apiKey: apiKey)
        return SpeechRecognitionResult(
            transcript: transcript,
            audioFileURL: recordingURL,
            waveformSamples: waveformSamples,
            duration: duration
        )
    }

    private func tearDownRecording(state: RecordingState) {
        state.audioEngine?.stop()
        state.audioEngine?.reset()
        state.audioFile = nil
        state.continuation?.finish()
        state.continuation = nil
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    // MARK: - Transcription API

    private func transcribeAudio(fileURL: URL, apiKey: String) async -> String {
        let boundary = UUID().uuidString
        guard let audioData = try? Data(contentsOf: fileURL) else { return "" }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let transcriptURL = apiBaseURL.appendingPathComponent("audio/transcriptions")

        var request = URLRequest(url: transcriptURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        do {
            let (data, _) = try await urlSession.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let text = json["text"] as? String else {
                return ""
            }
            return text
        } catch {
            return ""
        }
    }

    // MARK: - Audio Utilities

    private func recordingTapFormat(for inputNode: AVAudioInputNode) -> AVAudioFormat? {
        let hardwareFormat = inputNode.inputFormat(forBus: 0)
        guard hardwareFormat.sampleRate > 0, hardwareFormat.channelCount > 0 else {
            return nil
        }
        let nodeOutputFormat = inputNode.outputFormat(forBus: 0)
        if nodeOutputFormat.sampleRate == hardwareFormat.sampleRate,
           nodeOutputFormat.channelCount == hardwareFormat.channelCount {
            return nodeOutputFormat
        }
        return hardwareFormat
    }

    nonisolated private static func rmsLevel(from buffer: AVAudioPCMBuffer) -> Float {
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        guard let channelData = buffer.floatChannelData else { return 0 }
        var sum: Float = 0
        let channelCount = Int(buffer.format.channelCount)
        let sampleCount = frameLength * channelCount
        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for frame in 0..<frameLength {
                let sample = samples[frame]
                sum += sample * sample
            }
        }
        return sqrt(sum / Float(sampleCount))
    }
}
