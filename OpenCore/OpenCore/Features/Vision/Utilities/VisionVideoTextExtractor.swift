import AVFoundation
import Foundation
import UIKit
import Vision

/// Strategy for sampling video frames and running on-device OCR.
nonisolated enum VisionVideoTextExtractor: Sendable {
    private static let sampleFractions: [Double] = [0.0, 0.25, 0.5, 0.75]

    static func extract(from fileURL: URL) async throws -> String {
        let asset = AVURLAsset(url: fileURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = duration.seconds
        guard durationSeconds.isFinite, durationSeconds > 0 else {
            throw VisionExtractionError.unreadableContent
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1280, height: 1280)

        var uniqueLines: [String] = []
        var seenLines = Set<String>()

        for fraction in sampleFractions {
            let seconds = min(durationSeconds * fraction, max(durationSeconds - 0.05, 0))
            let time = CMTime(seconds: seconds, preferredTimescale: 600)
            let cgImage = try await generateImage(generator: generator, at: time)
            let lines = try recognizeLines(in: cgImage)
            for line in lines where seenLines.insert(line).inserted {
                uniqueLines.append(line)
            }
        }

        let text = uniqueLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw VisionExtractionError.noTextFound
        }
        return text
    }

    private static func generateImage(
        generator: AVAssetImageGenerator,
        at time: CMTime
    ) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            generator.generateCGImageAsynchronously(for: time) { image, _, error in
                if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: error ?? VisionExtractionError.unreadableContent)
                }
            }
        }
    }

    private static func recognizeLines(in cgImage: CGImage) throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        return (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
