import AVFoundation
import Foundation
import Testing

@testable import OpenCore

@Suite("Chat Voice Note Audio Preparer")
struct ChatVoiceNoteAudioPreparerTests {
    @Test("converts float microphone capture into playable mono PCM")
    func convertsFloatCapture() throws {
        let sourceURL = try makeFloatCaptureCAF(frameCount: 12_000)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let preparedURL = try ChatVoiceNoteAudioPreparer.savePlayableCopy(
            from: sourceURL,
            suggestedFilename: "voice-note.caf"
        )
        defer { try? FileManager.default.removeItem(at: preparedURL) }

        let preparedFile = try AVAudioFile(forReading: preparedURL)
        #expect(preparedFile.length > 0)
        #expect(preparedFile.processingFormat.commonFormat == .pcmFormatInt16)
        #expect(preparedFile.processingFormat.channelCount == 1)
        #expect(preparedFile.processingFormat.isInterleaved == true)
        #expect(try AVAudioPlayer(contentsOf: preparedURL).duration > 0)
    }

    @Test("converts stereo float captures into playable mono PCM")
    func convertsStereoFloatCapture() throws {
        let sourceURL = try makeStereoFloatCaptureCAF(frameCount: 12_000)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let preparedURL = try ChatVoiceNoteAudioPreparer.savePlayableCopy(
            from: sourceURL,
            suggestedFilename: "voice-note.caf"
        )
        defer { try? FileManager.default.removeItem(at: preparedURL) }

        let preparedFile = try AVAudioFile(forReading: preparedURL)
        #expect(preparedFile.length > 0)
        #expect(preparedFile.processingFormat.channelCount == 1)
        #expect(try AVAudioPlayer(contentsOf: preparedURL).duration > 0)
    }

    @Test("converts longer float captures without stalling")
    func convertsLongFloatCapture() throws {
        let sourceURL = try makeFloatCaptureCAF(frameCount: 129_600)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let preparedURL = try ChatVoiceNoteAudioPreparer.savePlayableCopy(
            from: sourceURL,
            suggestedFilename: "voice-note.caf"
        )
        defer { try? FileManager.default.removeItem(at: preparedURL) }

        let preparedFile = try AVAudioFile(forReading: preparedURL)
        #expect(preparedFile.length > 0)
        #expect(preparedFile.processingFormat.commonFormat == .pcmFormatInt16)
        #expect(abs(Double(preparedFile.length) - 129_600) < 2_000)
        #expect(try AVAudioPlayer(contentsOf: preparedURL).duration > 0)
    }

    private func makeFloatCaptureCAF(frameCount: AVAudioFrameCount) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("caf")
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1) else {
            throw NSError(domain: "ChatVoiceNoteAudioPreparerTests", code: 1)
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "ChatVoiceNoteAudioPreparerTests", code: 2)
        }
        buffer.frameLength = frameCount
        if let samples = buffer.floatChannelData?[0] {
            let fillValue: Float = frameCount > 16_000 ? 0 : Float(sin(Double(frameCount) / 120))
            for index in 0..<Int(frameCount) {
                samples[index] = fillValue
            }
        }
        try file.write(from: buffer)
        return url
    }

    private func makeStereoFloatCaptureCAF(frameCount: AVAudioFrameCount) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("caf")
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: 48_000,
            channels: 2
        ) else {
            throw NSError(domain: "ChatVoiceNoteAudioPreparerTests", code: 3)
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "ChatVoiceNoteAudioPreparerTests", code: 4)
        }
        buffer.frameLength = frameCount
        if let channels = buffer.floatChannelData {
            for channel in 0..<Int(format.channelCount) {
                let samples = channels[channel]
                for index in 0..<Int(frameCount) {
                    samples[index] = 0.01
                }
            }
        }
        try file.write(from: buffer)
        return url
    }
}
