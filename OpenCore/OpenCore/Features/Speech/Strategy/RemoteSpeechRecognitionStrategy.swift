import Foundation

/// Remote speech transcription via an OpenAI-compatible Whisper API.
///
/// Used as a post-recording fallback when on-device recognition produces
/// no usable transcript. The credential provider ID defaults to `"openai"`.
nonisolated final class RemoteSpeechRecognitionStrategy: SpeechPostRecordingTranscriber {
    private let credentialStore: CredentialStoring
    private let credentialProviderID: String
    private let apiBaseURL: URL
    private let model: String
    private let urlSession: URLSession

    /// - Parameters:
    ///   - credentialStore: Resolves the API key at transcription time.
    ///   - credentialProviderID: Provider ID used to look up the API key
    ///     in the credential store. Defaults to `"openai"`.
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
    }

    /// Whether an API credential is available for cloud transcription.
    nonisolated func hasCredential() -> Bool {
        credentialStore.secret(for: credentialProviderID) != nil
    }

    nonisolated func transcribe(
        audioFileURL: URL,
        waveformSamples: [Float],
        duration: TimeInterval
    ) async -> SpeechRecognitionResult? {
        guard let apiKey = credentialStore.secret(for: credentialProviderID) else {
            return SpeechRecognitionResult(
                transcript: "",
                audioFileURL: audioFileURL,
                waveformSamples: waveformSamples,
                duration: duration,
                failureMessage: Self.missingCredentialMessage
            )
        }

        switch await transcribeAudio(fileURL: audioFileURL, apiKey: apiKey) {
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

    private func transcribeAudio(fileURL: URL, apiKey: String) async -> TranscriptionOutcome {
        let boundary = UUID().uuidString
        guard let audioData = try? Data(contentsOf: fileURL), !audioData.isEmpty else {
            return .failure("Voice recording could not be read.")
        }

        let upload = Self.audioUploadMetadata(for: fileURL)

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"file\"; filename=\"\(upload.filename)\"\r\n"
                .data(using: .utf8)!
        )
        body.append("Content-Type: \(upload.mimeType)\r\n\r\n".data(using: .utf8)!)
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

    private struct AudioUploadMetadata: Sendable {
        let filename: String
        let mimeType: String
    }

    private static func audioUploadMetadata(for fileURL: URL) -> AudioUploadMetadata {
        switch fileURL.pathExtension.lowercased() {
        case "caf":
            return AudioUploadMetadata(filename: "audio.caf", mimeType: "audio/x-caf")
        case "wav":
            return AudioUploadMetadata(filename: "audio.wav", mimeType: "audio/wav")
        case "mp3":
            return AudioUploadMetadata(filename: "audio.mp3", mimeType: "audio/mpeg")
        default:
            return AudioUploadMetadata(filename: "audio.m4a", mimeType: "audio/mp4")
        }
    }

    private static let missingCredentialMessage =
        "Add an OpenAI API key in Settings to transcribe voice with the server."
}
