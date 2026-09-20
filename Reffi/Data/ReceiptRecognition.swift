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
        request.recognitionLanguages = ["en-US", "ko-KR"]
        request.automaticallyDetectsLanguage = true
        request.usesLanguageCorrection = true
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
        let fragments = textFragments(observations)
        var candidates = ReceiptParser.candidates(from: fragments)
        if !candidates.isEmpty, fragments.contains(where: { $0.text.unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) } }) {
            request.automaticallyDetectsLanguage = false
            request.recognitionLanguages = ["ko-KR", "en-US"]
            do {
                try VNImageRequestHandler(cgImage: cg, orientation: orientation).perform([request])
                let confirmation = textFragments(request.results ?? []).filter { $0.confidence >= 0.5 }
                candidates = ReceiptParser.corroborate(candidates, primary: fragments, confirmation: confirmation)
            } catch {
                // Keep the first pass and its review requirements if corroboration fails.
            }
        }
        return Page(observations: observations, fragments: fragments,
                    candidates: candidates, revision: request.revision)
    }

    /// Correct the reading coordinates using Vision's text quadrilaterals. A tilted
    /// price column must stay next to its product, even when their box centers differ.
    private static func textFragments(_ observations: [VNRecognizedTextObservation]) -> [ReceiptParser.TextFragment] {
        let angles = observations.compactMap { observation -> Double? in
            let dx = observation.topRight.x - observation.topLeft.x
            let dy = observation.topRight.y - observation.topLeft.y
            guard hypot(dx, dy) > 0.08 else { return nil }
            return atan2(dy, dx)
        }
        let sines = angles.map { sin($0) }.sorted()
        let cosines = angles.map { cos($0) }.sorted()
        let angle = angles.isEmpty ? 0 : atan2(sines[sines.count / 2], cosines[cosines.count / 2])
        let rotation = CGAffineTransform(rotationAngle: -angle)
        return observations.compactMap { observation in
            guard let text = observation.topCandidates(1).first, text.confidence >= 0.3 else { return nil }
            let points = [observation.topLeft, observation.topRight, observation.bottomLeft, observation.bottomRight]
                .map { CGPoint(x: $0.x - 0.5, y: $0.y - 0.5).applying(rotation) }
            let xs = points.map(\.x), ys = points.map(\.y)
            let bounds = CGRect(x: xs.min()! + 0.5, y: ys.min()! + 0.5,
                                width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
            return .init(text: text.string, bounds: bounds, confidence: text.confidence)
        }
    }
}
