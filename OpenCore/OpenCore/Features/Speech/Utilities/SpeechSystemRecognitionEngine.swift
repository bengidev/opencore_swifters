import AVFoundation
import Speech

/// On-device `SFSpeechRecognizer` + `AVAudioEngine` adapter.
nonisolated final class SpeechSystemRecognitionEngine: @unchecked Sendable {
    private let audioQueue = DispatchQueue(label: "io.github.bengidev.OpenCore.speech.audio")
    private let speechRecognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var latestTranscript = ""

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
            audioQueue.async {
                do {
                    try self.beginCapture(continuation: continuation)
                } catch {
                    continuation.yield(
                        .failed(SpeechRecognitionFallbackLogic.userFacingErrorMessage(systemMessage: error.localizedDescription))
                    )
                    continuation.finish()
                }
            }
        }
    }

    func stop() async -> String? {
        await withCheckedContinuation { continuation in
            audioQueue.async {
                let transcript = self.latestTranscript
                self.tearDownCapture()
                continuation.resume(
                    returning: transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        }
    }

    private func beginCapture(continuation: AsyncStream<SpeechRecognitionEvent>.Continuation) throws {
        tearDownCapture()

        guard let speechRecognizer else {
            throw SpeechSystemRecognitionError.localeUnavailable
        }

        guard speechRecognizer.isAvailable else {
            throw SpeechSystemRecognitionError.recognizerUnavailable
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let preferOnDevice = SpeechRecognitionFallbackLogic.prefersOnDeviceRecognition(
            supportsOnDevice: speechRecognizer.supportsOnDeviceRecognition
        )
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
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if preferOnDevice {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let text = result.bestTranscription.formattedString
                audioQueue.async {
                    self.latestTranscript = text
                }
                if result.isFinal {
                    continuation.yield(.final(text))
                    continuation.finish()
                } else {
                    continuation.yield(.partial(text))
                }
                return
            }

            if let error {
                let message = error.localizedDescription
                if SpeechRecognitionFallbackLogic.shouldRetryWithServerRecognition(
                    errorMessage: message,
                    attemptedOnDevice: preferOnDevice
                ) {
                    audioQueue.async {
                        self.retryWithServerRecognition(
                            speechRecognizer: speechRecognizer,
                            continuation: continuation
                        )
                    }
                    return
                }

                continuation.yield(
                    .failed(SpeechRecognitionFallbackLogic.userFacingErrorMessage(systemMessage: message))
                )
                continuation.finish()
                return
            }

            continuation.finish()
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
            let level = Self.rmsLevel(from: buffer)
            continuation.yield(.audioLevel(level))
        }

        audioEngine.prepare()
        try audioEngine.start()
        continuation.yield(.ready)
    }

    private func retryWithServerRecognition(
        speechRecognizer: SFSpeechRecognizer,
        continuation: AsyncStream<SpeechRecognitionEvent>.Continuation
    ) {
        tearDownCapture()
        do {
            try startCapture(
                speechRecognizer: speechRecognizer,
                preferOnDevice: false,
                continuation: continuation
            )
        } catch {
            continuation.yield(
                .failed(SpeechRecognitionFallbackLogic.userFacingErrorMessage(systemMessage: error.localizedDescription))
            )
            continuation.finish()
        }
    }

    private func tearDownCapture() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        latestTranscript = ""
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

    var errorDescription: String? {
        switch self {
        case .localeUnavailable:
            "Speech recognition is not available for your language on this device."
        case .recognizerUnavailable:
            "Speech recognition is temporarily unavailable."
        }
    }
}
