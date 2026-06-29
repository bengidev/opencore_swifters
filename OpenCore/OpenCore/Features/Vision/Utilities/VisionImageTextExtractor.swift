import Foundation
import UIKit
import Vision

/// Strategy for on-device OCR from still-image payloads.
nonisolated enum VisionImageTextExtractor: Sendable {
    static func extract(from data: Data) async throws -> String {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else {
            throw VisionExtractionError.unreadableContent
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        let lines = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw VisionExtractionError.noTextFound
        }
        return text
    }
}
