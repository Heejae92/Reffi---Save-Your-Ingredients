import Foundation
import Testing
import UIKit
import Vision
@testable import Reffi

/// Opt-in evaluation of locally downloaded public images. No network or inventory writes.
/// Set REFFI_RECEIPT_CORPUS to a directory containing manifest.json and images/.
struct ReceiptCorpusTests {
    @Test @MainActor func exportPublicReceiptCorpus() throws {
        guard let directory = ProcessInfo.processInfo.environment["REFFI_RECEIPT_CORPUS"] else { return }
        let root = URL(fileURLWithPath: directory)
        let inputs = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("manifest.json"))) as! [[String: Any]]
        var results: [[String: Any]] = []
        for input in inputs where input["status"] as? String == "downloaded" {
            let id = input["id"] as! String
            let started = Date()
            var result: [String: Any] = ["id": id]
            do {
                let path = root.appendingPathComponent(input["path"] as! String).path
                let image = try #require(UIImage(contentsOfFile: path))
                let page = try ReceiptRecognition.recognize(image)
                let observations = page.observations
                let fragments = page.fragments
                let lines = page.lines
                func candidateJSON(_ candidates: [ReceiptParser.Candidate]) -> [[String: Any]] {
                    candidates.map { ["rawLine": $0.rawLine, "name": $0.name,
                                      "canonicalID": $0.canonicalID ?? "", "quantity": $0.quantity.value,
                                      "unit": $0.quantity.unit.rawValue, "automatic": !$0.requiresConfirmation,
                                      "quantityNeedsConfirmation": $0.quantityNeedsConfirmation] }
                }
                result["observations"] = observations.compactMap { observation -> [String: Any]? in
                    guard let text = observation.topCandidates(1).first else { return nil }
                    let b = observation.boundingBox
                    return ["text": text.string, "confidence": text.confidence,
                            "bounds": [b.minX, b.minY, b.width, b.height]]
                }
                result["visionRevision"] = page.revision
                result["lines"] = lines
                result["containsReturn"] = page.containsReturn
                result["containsMultipleReceipts"] = page.containsMultipleReceipts
                result["candidates"] = candidateJSON(page.candidates)
                if let expected = input["verifiedQuantities"] as? [[String: Any]] {
                    // Each auto-selected row must have a human-checked identity AND
                    // amount. Consume matches so duplicate additions cannot pass.
                    var remaining = expected
                    for candidate in page.candidates where !candidate.requiresConfirmation {
                        let match = remaining.firstIndex {
                            $0["canonicalID"] as? String == candidate.canonicalID &&
                            $0["unit"] as? String == candidate.quantity.unit.rawValue &&
                            abs(($0["quantity"] as? Double ?? -1) - candidate.quantity.value) < 0.0001
                        }
                        #expect(match != nil, "Unverified automatic quantity in \(id): \(candidate.canonicalID ?? "?") \(candidate.quantity)")
                        if let match { remaining.remove(at: match) }
                    }
                }
                // Diagnostic only: isolate the effect of the row-rejoining step.
                result["ungroupedCandidates"] = candidateJSON(ReceiptParser.candidates(from: fragments.map(\.text)))
                if let groundTruth = input["productLines"] as? [String] {
                    result["oracleCandidates"] = candidateJSON(ReceiptParser.candidates(from: groundTruth))
                    result["oracleLineMatches"] = groundTruth.map { line -> [String: Any] in
                        ["line": line, "candidates": candidateJSON(ReceiptParser.candidates(from: [line]))]
                    }
                }
                result["status"] = "ok"
            } catch {
                result["status"] = "error"
                result["error"] = String(describing: error)
            }
            result["elapsedSeconds"] = Date().timeIntervalSince(started)
            results.append(result)
            print("CORPUS \(id): \(result["status"]!)")
        }
        let report: [String: Any] = ["os": ProcessInfo.processInfo.operatingSystemVersionString,
                                   "generatedAt": ISO8601DateFormatter().string(from: Date()), "results": results]
        let output = root.appendingPathComponent("results.json")
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: output)
        #expect(!results.isEmpty, "No downloaded corpus images were evaluated")
        #expect(results.allSatisfy { $0["status"] as? String == "ok" }, "Inspect per-image errors in results.json")
    }
}
