import Foundation

/// Remote speech transcription via the active provider's OpenAI-compatible Whisper API.
nonisolated final class RemoteSpeechRecognitionStrategy: SpeechPostRecordingTranscriber {
    private let credentialStore: CredentialStoring
    private let contextResolver: @Sendable () -> SpeechRemoteTranscriptionContext?
    private let model: String
    private let urlSession: URLSession

    init(
        credentialStore: CredentialStoring,
        contextResolver: @escaping @Sendable () -> SpeechRemoteTranscriptionContext?,
        model: String = "whisper-1",
        urlSession: URLSession = .shared
    ) {
        self.credentialStore = credentialStore
        self.contextResolver = contextResolver
        self.model = model
        self.urlSession = urlSession
    }

    /// Whether an API credential is available for the active provider.
    nonisolated func hasCredential() -> Bool {
        guard let context = contextResolver() else { return false }
        return credentialStore.secret(for: context.providerID) != nil
    }

    nonisolated func transcribe(
        audioFileURL: URL,
        waveformSamples: [Float],
        duration: TimeInterval
    ) async -> SpeechRecognitionResult? {
        guard let context = contextResolver() else {
            return missingCredentialResult(
                audioFileURL: audioFileURL,
                waveformSamples: waveformSamples,
                duration: duration
            )
        }

        guard let apiKey = credentialStore.secret(for: context.providerID) else {
            return missingCredentialResult(
                audioFileURL: audioFileURL,
                waveformSamples: waveformSamples,
                duration: duration
            )
        }

        let preparedUpload: SpeechWhisperUploadPreparer.PreparedUpload
        do {
            preparedUpload = try SpeechWhisperUploadPreparer.prepareUpload(from: audioFileURL)
        } catch {
            return SpeechRecognitionResult(
                transcript: "",
                audioFileURL: audioFileURL,
                waveformSamples: waveformSamples,
                duration: duration,
                failureMessage: "Voice recording could not be prepared for transcription."
            )
        }

        defer {
            if preparedUpload.shouldDeleteAfterUpload {
                try? FileManager.default.removeItem(at: preparedUpload.fileURL)
            }
        }

        switch await transcribeAudio(
            fileURL: preparedUpload.fileURL,
            filename: preparedUpload.filename,
            mimeType: preparedUpload.mimeType,
            apiKey: apiKey,
            context: context
        ) {
        case let .success(transcript):
            return SpeechRecognitionResult(
                transcript: transcript,
                audioFileURL: audioFileURL,
                waveformSamples: waveformSamples,
                duration: duration
            )
        case let .failure(message):
            return SpeechRecognitionResult(
                transcript: "",
                audioFileURL: audioFileURL,
                waveformSamples: waveformSamples,
                duration: duration,
                failureMessage: message
            )
        }
    }

    // MARK: - Transcription API

    private enum TranscriptionOutcome: Sendable {
        case success(String)
        case failure(String)
    }

    private func transcribeAudio(
        fileURL: URL,
        filename: String,
        mimeType: String,
        apiKey: String,
        context: SpeechRemoteTranscriptionContext
    ) async -> TranscriptionOutcome {
        let boundary = UUID().uuidString
        guard let audioData = try? Data(contentsOf: fileURL), !audioData.isEmpty else {
            return .failure("Voice recording could not be read.")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n"
                .data(using: .utf8)!
        )
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: context.audioTranscriptionsURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        for (header, value) in context.defaultHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }
        request.httpBody = body

        do {
            let (data, response) = try await urlSession.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                return .failure(Self.httpFailureMessage(statusCode: httpResponse.statusCode))
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let text = json["text"] as? String else {
                return .failure("Voice transcription returned an unexpected response.")
            }
            return .success(text)
        } catch {
            return .failure("Voice transcription failed. Check your network connection.")
        }
    }

    private func missingCredentialResult(
        audioFileURL: URL,
        waveformSamples: [Float],
        duration: TimeInterval
    ) -> SpeechRecognitionResult {
        SpeechRecognitionResult(
            transcript: "",
            audioFileURL: audioFileURL,
            waveformSamples: waveformSamples,
            duration: duration,
            failureMessage: Self.missingCredentialMessage
        )
    }

    private static func httpFailureMessage(statusCode: Int) -> String {
        switch statusCode {
        case 401, 403:
            "Voice transcription failed. Check your API key in Settings."
        case 413:
            "Voice recording is too large to transcribe."
        case 429:
            "Voice transcription is rate limited. Try again shortly."
        default:
            "Voice transcription failed (HTTP \(statusCode))."
        }
    }

    private static let missingCredentialMessage =
        "Add an API key for your selected provider in Settings to use server transcription."
}
