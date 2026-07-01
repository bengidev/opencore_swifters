import AVFAudio
import AVFoundation
import Speech

/// On-device `SFSpeechRecognizer` + `AVAudioEngine` adapter.
nonisolated final class SpeechSystemRecognitionEngine: @unchecked Sendable {
    private let audioQueue = DispatchQueue(label: "io.github.bengidev.OpenCore.speech.audio")
    private let speechRecognizer: SFSpeechRecognizer?
    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var latestTranscript = ""
    private var isInputTapInstalled = false
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?
    private var recordingStartedAt: Date?
    /// Bumped on teardown so audio-tap and recognition callbacks ignore stale work.
    private var captureGeneration: UInt64 = 0
    private var lastStopResult: SpeechRecognitionResult?

    init(locale: Locale = .current) {
        let resolvedLocale = Self.resolvedLocale(for: locale) ?? locale
        speechRecognizer = SFSpeechRecognizer(locale: resolvedLocale)
    }

    nonisolated static func authorizationStatus() -> SpeechAuthorizationStatus {
        mapAuthorizationStatus(SFSpeechRecognizer.authorizationStatus())
    }

    nonisolated static func requestAuthorization() async -> SpeechAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: mapAuthorizationStatus(status))
            }
        }
    }

    func start() -> AsyncStream<SpeechRecognitionEvent> {
        AsyncStream { continuation in
            continuation.onTermination = { @Sendable _ in
                self.audioQueue.async {
                    guard self.lastStopResult == nil else { return }
                    self.tearDownCapture()
                }
            }

            audioQueue.async {
                do {
                    try self.beginCapture(continuation: continuation)
                } catch {
                    self.failCapture(
                        systemMessage: error.localizedDescription,
                        attemptedOnDevice: false,
                        continuation: continuation
                    )
                }
            }
        }
    }

    func stop() async -> SpeechRecognitionResult? {
        await withCheckedContinuation { continuation in
            audioQueue.async {
                if let lastStopResult = self.lastStopResult {
                    continuation.resume(returning: lastStopResult)
                    return
                }

                let transcript = self.latestTranscript
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let audioFileURL = self.recordingURL
                let duration = self.recordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
                let result = SpeechRecognitionResult(
                    transcript: transcript,
                    audioFileURL: audioFileURL,
                    duration: duration
                )
                self.lastStopResult = result
                self.tearDownCapture()
                self.latestTranscript = ""
                continuation.resume(returning: result)
            }
        }
    }

    private func beginCapture(continuation: AsyncStream<SpeechRecognitionEvent>.Continuation) throws {
        tearDownCapture()
        lastStopResult = nil
        latestTranscript = ""
        recordingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("caf")
        recordingStartedAt = Date()

        guard let speechRecognizer else {
            throw SpeechSystemRecognitionError.localeUnavailable
        }

        guard speechRecognizer.isAvailable else {
            throw SpeechSystemRecognitionError.recognizerUnavailable
        }

        guard AVAudioApplication.shared.recordPermission == .granted else {
            throw SpeechSystemRecognitionError.microphoneDenied
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.duckOthers, .defaultToSpeaker, .allowBluetooth]
        )
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let preferOnDevice = speechRecognizer.supportsOnDeviceRecognition
        try startCapture(
            speechRecognizer: speechRecognizer,
            preferOnDevice: preferOnDevice,
            continuation: continuation
        )
    }

    private func startCapture(
        speechRecognizer: SFSpeechRecognizer,
        preferOnDevice: Bool,
        continuation: AsyncStream<SpeechRecognitionEvent>.Continuation
    ) throws {
        captureGeneration &+= 1
        let generation = captureGeneration

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if preferOnDevice {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            audioQueue.async {
                guard self.captureGeneration == generation else { return }

                if let result {
                    let text = result.bestTranscription.formattedString
                    self.latestTranscript = text
                    if result.isFinal {
                        self.deliver(.final(text), continuation: continuation)
                    } else {
                        self.deliver(.partial(text), continuation: continuation)
                    }
                    return
                }

                if let error {
                    let nsError = error as NSError
                    let message = error.localizedDescription
                    if SpeechRecognitionFallbackLogic.shouldRetryWithServerRecognition(
                        errorMessage: message,
                        attemptedOnDevice: preferOnDevice,
                        error: nsError
                    ) {
                        self.retryWithServerRecognition(
                            speechRecognizer: speechRecognizer,
                            continuation: continuation
                        )
                        return
                    }

                    self.failCapture(
                        systemMessage: message,
                        attemptedOnDevice: preferOnDevice,
                        continuation: continuation
                    )
                    return
                }

                // Recognition segment ended without a terminal error. Keep the
                // microphone capture alive until `stop()` so voice notes are not
                // truncated when the recognizer pauses between utterances.
            }
        }

        let inputNode = audioEngine.inputNode
        try installInputTap(on: inputNode, request: request, continuation: continuation)

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            tearDownCapture()
            throw error
        }
        deliver(.ready, continuation: continuation)
    }

    private func installInputTap(
        on inputNode: AVAudioInputNode,
        request: SFSpeechAudioBufferRecognitionRequest,
        continuation: AsyncStream<SpeechRecognitionEvent>.Continuation
    ) throws {
        removeInputTapIfNeeded(from: inputNode)

        let tapFormat = Self.recordingTapFormat(for: inputNode)
        guard let tapFormat else {
            throw SpeechSystemRecognitionError.audioFormatUnavailable
        }

        if let recordingURL {
            audioFile = try AVAudioFile(forWriting: recordingURL, settings: tapFormat.settings)
        }

        let generation = captureGeneration
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: tapFormat) { [weak self] buffer, _ in
            guard let self else { return }
            guard self.captureGeneration == generation else { return }
            request.append(buffer)
            try? self.audioFile?.write(from: buffer)
            let level = Self.rmsLevel(from: buffer)
            self.audioQueue.async {
                guard self.captureGeneration == generation else { return }
                continuation.yield(.audioLevel(level))
            }
        }
        isInputTapInstalled = true
    }

    private func removeInputTapIfNeeded(from inputNode: AVAudioInputNode) {
        guard isInputTapInstalled else { return }
        inputNode.removeTap(onBus: 0)
        isInputTapInstalled = false
    }

    /// Picks a tap format that matches the live hardware input rate (often 48 kHz on device, not 44.1 kHz).
    nonisolated private static func recordingTapFormat(for inputNode: AVAudioInputNode) -> AVAudioFormat? {
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

    private func retryWithServerRecognition(
        speechRecognizer: SFSpeechRecognizer,
        continuation: AsyncStream<SpeechRecognitionEvent>.Continuation
    ) {
        tearDownCapture()
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            try startCapture(
                speechRecognizer: speechRecognizer,
                preferOnDevice: false,
                continuation: continuation
            )
        } catch {
            failCapture(
                systemMessage: error.localizedDescription,
                attemptedOnDevice: false,
                continuation: continuation
            )
        }
    }

    private func deliver(
        _ event: SpeechRecognitionEvent,
        continuation: AsyncStream<SpeechRecognitionEvent>.Continuation
    ) {
        continuation.yield(event)
    }

    private func failCapture(
        systemMessage: String,
        attemptedOnDevice: Bool,
        continuation: AsyncStream<SpeechRecognitionEvent>.Continuation
    ) {
        deliver(
            .failed(
                SpeechRecognitionFallbackLogic.userFacingErrorMessage(
                    systemMessage: systemMessage,
                    attemptedOnDevice: attemptedOnDevice
                )
            ),
            continuation: continuation
        )
        complete(continuation: continuation)
    }

    private func complete(continuation: AsyncStream<SpeechRecognitionEvent>.Continuation) {
        tearDownCapture()
        continuation.finish()
    }

    private func tearDownCapture() {
        captureGeneration &+= 1

        let inputNode = audioEngine.inputNode
        removeInputTapIfNeeded(from: inputNode)

        audioFile = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.reset()
        audioEngine = AVAudioEngine()

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        recordingStartedAt = nil
        deactivateAudioSession()
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    nonisolated private static func resolvedLocale(for preferred: Locale) -> Locale? {
        SpeechRecognizerLocaleResolver.resolve(preferred: preferred) { locale in
            guard let recognizer = SFSpeechRecognizer(locale: locale) else { return false }
            return recognizer.isAvailable
        }
    }

    nonisolated private static func rmsLevel(from buffer: AVAudioPCMBuffer) -> Float {
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        switch buffer.format.commonFormat {
        case .pcmFormatFloat32:
            guard let channelData = buffer.floatChannelData else { return 0 }
            return rmsFromFloatChannels(channelData, channelCount: Int(buffer.format.channelCount), frameLength: frameLength)
        case .pcmFormatInt16:
            guard let channelData = buffer.int16ChannelData else { return 0 }
            return rmsFromInt16Channels(channelData, channelCount: Int(buffer.format.channelCount), frameLength: frameLength)
        default:
            return 0
        }
    }

    nonisolated private static func rmsFromFloatChannels(
        _ channelData: UnsafePointer<UnsafeMutablePointer<Float>>,
        channelCount: Int,
        frameLength: Int
    ) -> Float {
        guard channelCount > 0 else { return 0 }

        var sum: Float = 0
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

    nonisolated private static func rmsFromInt16Channels(
        _ channelData: UnsafePointer<UnsafeMutablePointer<Int16>>,
        channelCount: Int,
        frameLength: Int
    ) -> Float {
        guard channelCount > 0 else { return 0 }

        var sum: Float = 0
        let sampleCount = frameLength * channelCount
        let scale: Float = 1.0 / Float(Int16.max)
        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for frame in 0..<frameLength {
                let sample = Float(samples[frame]) * scale
                sum += sample * sample
            }
        }
        return sqrt(sum / Float(sampleCount))
    }

    nonisolated private static func mapAuthorizationStatus(
        _ status: SFSpeechRecognizerAuthorizationStatus
    ) -> SpeechAuthorizationStatus {
        switch status {
        case .authorized: .authorized
        case .denied, .restricted: .denied
        case .notDetermined: .notDetermined
        @unknown default: .denied
        }
    }
}

enum SpeechSystemRecognitionError: LocalizedError {
    case localeUnavailable
    case recognizerUnavailable
    case audioFormatUnavailable
    case microphoneDenied

    var errorDescription: String? {
        switch self {
        case .localeUnavailable:
            "Speech recognition is not available for your language on this device."
        case .recognizerUnavailable:
            "Speech recognition is temporarily unavailable."
        case .audioFormatUnavailable:
            "Could not configure microphone audio for recording."
        case .microphoneDenied:
            "Microphone access is required for voice input."
        }
    }
}
