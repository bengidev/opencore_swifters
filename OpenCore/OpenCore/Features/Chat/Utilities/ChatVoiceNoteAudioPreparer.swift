import AVFoundation
import Foundation

enum ChatVoiceNoteAudioPreparerError: LocalizedError {
    case emptyRecording
    case unsupportedFormat
    case conversionFailed

    var errorDescription: String? {
        switch self {
        case .emptyRecording:
            "Voice note recording was empty."
        case .unsupportedFormat:
            "Voice note audio format is not supported."
        case .conversionFailed:
            "Voice note could not be prepared for playback."
        }
    }
}

/// Converts captured microphone audio into a playback-friendly file for chat bubbles.
nonisolated enum ChatVoiceNoteAudioPreparer: Sendable {
    private static let inputChunkFrames: AVAudioFrameCount = 8_192

    static func savePlayableCopy(
        from sourceURL: URL,
        suggestedFilename: String
    ) throws -> URL {
        let sourceFile = try AVAudioFile(forReading: sourceURL)
        guard sourceFile.length > 0 else {
            throw ChatVoiceNoteAudioPreparerError.emptyRecording
        }

        if isAlreadyPlayable(sourceFile.processingFormat) {
            return try ChatAttachmentStore.save(
                copyingFrom: sourceURL,
                suggestedFilename: playableFilename(for: suggestedFilename)
            )
        }

        let playableURL = try ChatAttachmentStore.makeAttachmentURL(
            suggestedFilename: playableFilename(for: suggestedFilename)
        )
        try convertToPlayablePCM(sourceFile: sourceFile, destinationURL: playableURL)
        guard savedFileIsPlayable(at: playableURL) else {
            try? FileManager.default.removeItem(at: playableURL)
            throw ChatVoiceNoteAudioPreparerError.conversionFailed
        }
        return playableURL
    }

    private static func isAlreadyPlayable(_ format: AVAudioFormat) -> Bool {
        format.commonFormat == .pcmFormatInt16
            && format.channelCount == 1
            && format.isInterleaved
    }

    private static func playableFilename(for suggestedFilename: String) -> String {
        let stem = ((suggestedFilename as NSString).deletingPathExtension as NSString).lastPathComponent
        return "\(stem).caf"
    }

    private static func savedFileIsPlayable(at url: URL) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? NSNumber,
              fileSize.intValue > 0 else {
            return false
        }
        guard let file = try? AVAudioFile(forReading: url), file.length > 0 else {
            return false
        }
        return true
    }

    private static func convertToPlayablePCM(
        sourceFile: AVAudioFile,
        destinationURL: URL
    ) throws {
        let sourceFormat = sourceFile.processingFormat
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sourceFormat.sampleRate,
            channels: 1,
            interleaved: true
        ) else {
            throw ChatVoiceNoteAudioPreparerError.unsupportedFormat
        }

        let outputFile = try AVAudioFile(forWriting: destinationURL, settings: outputFormat.settings)

        if canUseDirectFloatConversion(sourceFormat: sourceFormat, outputFormat: outputFormat) {
            try convertFloatPCMToInt16Mono(
                sourceFile: sourceFile,
                sourceFormat: sourceFormat,
                outputFormat: outputFormat,
                outputFile: outputFile
            )
            return
        }

        try convertWithAudioConverter(
            sourceFile: sourceFile,
            sourceFormat: sourceFormat,
            writeFormat: outputFile.processingFormat,
            outputFile: outputFile
        )
    }

    private static func canUseDirectFloatConversion(
        sourceFormat: AVAudioFormat,
        outputFormat: AVAudioFormat
    ) -> Bool {
        sourceFormat.commonFormat == .pcmFormatFloat32
            && sourceFormat.sampleRate == outputFormat.sampleRate
    }

    private static func convertFloatPCMToInt16Mono(
        sourceFile: AVAudioFile,
        sourceFormat: AVAudioFormat,
        outputFormat: AVAudioFormat,
        outputFile: AVAudioFile
    ) throws {
        guard let inputBuffer = AVAudioPCMBuffer(
            pcmFormat: sourceFormat,
            frameCapacity: inputChunkFrames
        ), let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: inputChunkFrames
        ) else {
            throw ChatVoiceNoteAudioPreparerError.unsupportedFormat
        }

        let channelCount = Int(sourceFormat.channelCount)
        sourceFile.framePosition = 0

        while sourceFile.framePosition < sourceFile.length {
            let framesLeft = AVAudioFrameCount(sourceFile.length - sourceFile.framePosition)
            let framesToRead = min(inputChunkFrames, framesLeft)
            inputBuffer.frameLength = 0
            try sourceFile.read(into: inputBuffer, frameCount: framesToRead)

            let frameLength = Int(inputBuffer.frameLength)
            guard frameLength > 0,
                  let outputSamples = outputBuffer.int16ChannelData?[0] else {
                continue
            }

            outputBuffer.frameLength = AVAudioFrameCount(frameLength)

            switch channelCount {
            case 1:
                guard let inputSamples = inputBuffer.floatChannelData?[0] else {
                    throw ChatVoiceNoteAudioPreparerError.unsupportedFormat
                }
                for index in 0..<frameLength {
                    outputSamples[index] = quantizeFloatSample(inputSamples[index])
                }
            default:
                guard let inputChannels = inputBuffer.floatChannelData else {
                    throw ChatVoiceNoteAudioPreparerError.unsupportedFormat
                }
                for frame in 0..<frameLength {
                    var sum: Float = 0
                    for channel in 0..<channelCount {
                        sum += inputChannels[channel][frame]
                    }
                    outputSamples[frame] = quantizeFloatSample(sum / Float(channelCount))
                }
            }

            try outputFile.write(from: outputBuffer)
        }
    }

    private static func convertWithAudioConverter(
        sourceFile: AVAudioFile,
        sourceFormat: AVAudioFormat,
        writeFormat: AVAudioFormat,
        outputFile: AVAudioFile
    ) throws {
        guard let converter = AVAudioConverter(from: sourceFormat, to: writeFormat) else {
            throw ChatVoiceNoteAudioPreparerError.unsupportedFormat
        }

        let outputCapacity = outputFrameCapacity(
            inputCapacity: inputChunkFrames,
            sourceFormat: sourceFormat,
            outputFormat: writeFormat
        )

        guard let inputBuffer = AVAudioPCMBuffer(
            pcmFormat: sourceFormat,
            frameCapacity: inputChunkFrames
        ), let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: writeFormat,
            frameCapacity: outputCapacity
        ) else {
            throw ChatVoiceNoteAudioPreparerError.unsupportedFormat
        }

        sourceFile.framePosition = 0
        var reachedEOF = false

        while true {
            var conversionError: NSError?
            let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
                if reachedEOF {
                    outStatus.pointee = .endOfStream
                    return nil
                }

                if sourceFile.framePosition >= sourceFile.length {
                    reachedEOF = true
                    outStatus.pointee = .endOfStream
                    return nil
                }

                let framesLeft = AVAudioFrameCount(sourceFile.length - sourceFile.framePosition)
                let framesToRead = min(inputChunkFrames, framesLeft)
                inputBuffer.frameLength = 0

                do {
                    try sourceFile.read(into: inputBuffer, frameCount: framesToRead)
                } catch {
                    reachedEOF = true
                    outStatus.pointee = .endOfStream
                    return nil
                }

                guard inputBuffer.frameLength > 0 else {
                    reachedEOF = true
                    outStatus.pointee = .endOfStream
                    return nil
                }

                outStatus.pointee = .haveData
                return inputBuffer
            }

            if status == .error {
                throw conversionError ?? ChatVoiceNoteAudioPreparerError.conversionFailed
            }

            if outputBuffer.frameLength > 0 {
                try outputFile.write(from: outputBuffer)
            }

            switch status {
            case .haveData, .inputRanDry:
                continue
            case .endOfStream:
                return
            @unknown default:
                return
            }
        }
    }

    private static func quantizeFloatSample(_ sample: Float) -> Int16 {
        let clamped = min(max(sample, -1), 1)
        return Int16(clamped * Float(Int16.max))
    }

    private static func outputFrameCapacity(
        inputCapacity: AVAudioFrameCount,
        sourceFormat: AVAudioFormat,
        outputFormat: AVAudioFormat
    ) -> AVAudioFrameCount {
        let sampleRateRatio = outputFormat.sampleRate / sourceFormat.sampleRate
        let channelRatio = Double(outputFormat.channelCount) / Double(sourceFormat.channelCount)
        let estimated = Double(inputCapacity) * sampleRateRatio * max(channelRatio, 1)
        return AVAudioFrameCount(estimated.rounded(.up)) + 1_024
    }
}
