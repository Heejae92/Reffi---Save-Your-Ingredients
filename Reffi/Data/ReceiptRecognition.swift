import UIKit
import Vision

/// Shared on-device pipeline for the app and the public-image evaluation harness.
enum ReceiptRecognition {
    struct Page {
        let observations: [VNRecognizedTextObservation]
        let fragments: [ReceiptParser.TextFragment]
        let candidates: [ReceiptParser.Candidate]
        let revision: Int
        var lines: [String] { ReceiptParser.readingLines(from: fragments) }
        var containsMultipleReceipts: Bool { ReceiptParser.containsMultipleReceipts(fragments) }
        var containsReturn: Bool { ReceiptParser.containsReturnTransaction(lines) }
    }

    static func recognize(_ image: UIImage) throws -> Page {
        guard let cg = image.cgImage else { throw CocoaError(.fileReadCorruptFile) }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ko-KR", "en-US"]
        request.usesLanguageCorrection = true
        request.customWords = IngredientLexicon.shared.entries.flatMap { $0.names.en + $0.names.ko }
        request.minimumTextHeight = 0.005
        let orientation: CGImagePropertyOrientation = switch image.imageOrientation {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        case .upMirrored: .upMirrored
        case .downMirrored: .downMirrored
        case .leftMirrored: .leftMirrored
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
        try VNImageRequestHandler(cgImage: cg, orientation: orientation).perform([request])
        let observations = request.results ?? []
        let fragments = observations.compactMap { observation -> ReceiptParser.TextFragment? in
            guard let text = observation.topCandidates(1).first, text.confidence >= 0.3 else { return nil }
            return .init(text: text.string, bounds: observation.boundingBox, confidence: text.confidence)
        }
        return Page(observations: observations, fragments: fragments,
                    candidates: ReceiptParser.candidates(from: fragments), revision: request.revision)
    }
}
