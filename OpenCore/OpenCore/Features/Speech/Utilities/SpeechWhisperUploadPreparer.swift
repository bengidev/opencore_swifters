import AVFoundation
import Foundation

/// Prepares captured audio for OpenAI-compatible `/audio/transcriptions` uploads.
nonisolated enum SpeechWhisperUploadPreparer: Sendable {
    private static let supportedExtensions: Set<String> = [
        "flac", "mp3", "mp4", "mpeg", "mpga", "m4a", "ogg", "wav", "webm"
    ]

    struct PreparedUpload: Sendable {
        let fileURL: URL
        let filename: String
        let mimeType: String
        /// When true, callers should delete `fileURL` after the upload completes.
        let shouldDeleteAfterUpload: Bool
    }

    enum Error: Swift.Error {
        case unsupportedFormat
        case conversionFailed
    }

    static func prepareUpload(from sourceURL: URL) throws -> PreparedUpload {
        let ext = sourceURL.pathExtension.lowercased()
        if supportedExtensions.contains(ext) {
            return PreparedUpload(
                fileURL: sourceURL,
                filename: uploadFilename(for: ext),
                mimeType: mimeType(for: ext),
                shouldDeleteAfterUpload: false
            )
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        try convertToWAV(from: sourceURL, outputURL: outputURL)
        return PreparedUpload(
            fileURL: outputURL,
            filename: "audio.wav",
            mimeType: "audio/wav",
            shouldDeleteAfterUpload: true
        )
    }

    private static func convertToWAV(from sourceURL: URL, outputURL: URL) throws {
        let sourceFile = try AVAudioFile(forReading: sourceURL)
        let sourceFormat = sourceFile.processingFormat

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sourceFormat.sampleRate,
            AVNumberOfChannelsKey: sourceFormat.channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        guard let outputFormat = AVAudioFormat(settings: outputSettings),
              let converter = AVAudioConverter(from: sourceFormat, to: outputFormat) else {
            throw Error.unsupportedFormat
        }

        let outputFile = try AVAudioFile(forWriting: outputURL, settings: outputSettings)
        let inputCapacity: AVAudioFrameCount = 4_096
        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: inputCapacity),
              let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: inputCapacity) else {
            throw Error.unsupportedFormat
        }

        while sourceFile.framePosition < sourceFile.length {
            let framesRemaining = AVAudioFrameCount(sourceFile.length - sourceFile.framePosition)
            let frameCount = min(inputCapacity, framesRemaining)
            try sourceFile.read(into: inputBuffer, frameCount: frameCount)

            var conversionError: NSError?
            var inputConsumed = false
            let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
                if inputConsumed {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                inputConsumed = true
                outStatus.pointee = .haveData
                return inputBuffer
            }

            if status == .error {
                throw conversionError ?? Error.conversionFailed
            }
            try outputFile.write(from: outputBuffer)
        }
    }

    private static func uploadFilename(for ext: String) -> String {
        "audio.\(ext)"
    }

    private static func mimeType(for ext: String) -> String {
        switch ext {
        case "wav": "audio/wav"
        case "mp3", "mpeg", "mpga": "audio/mpeg"
        case "m4a", "mp4": "audio/mp4"
        case "webm": "audio/webm"
        case "ogg": "audio/ogg"
        case "flac": "audio/flac"
        default: "application/octet-stream"
        }
    }
}
