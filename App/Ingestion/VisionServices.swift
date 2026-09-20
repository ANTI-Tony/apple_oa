import Foundation
import ReportCore
import Vision

/// On-device image understanding. Nothing leaves the Mac.
///
/// Both helpers are suggestions the user reviews: OCR results open in the
/// paste review sheet, alt text lands in an editable field.
enum VisionServices {
    /// Recognised text lines, ordered top to bottom then left to right.
    static func recognizeText(in data: Data) async throws -> [String] {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            let handler = VNImageRequestHandler(data: data, options: [:])
            try handler.perform([request])
            let observations = request.results ?? []
            let sorted = observations.sorted { lhs, rhs in
                let dy = lhs.boundingBox.midY - rhs.boundingBox.midY
                if abs(dy) > 0.015 {
                    return dy > 0
                }
                return lhs.boundingBox.minX < rhs.boundingBox.minX
            }
            return sorted.compactMap { $0.topCandidates(1).first?.string }
        }.value
    }

    /// Metrics found in a screenshot of a dashboard or table.
    static func extractMetrics(from data: Data) async throws -> MetricsParseResult? {
        let lines = try await recognizeText(in: data)
        let paired = MetricsParser.pairLabelValueLines(lines)
        return MetricsParser.parse(paired.joined(separator: "\n"), allowBareNumbers: true)
    }

    /// A rough description from the image classifier, to be edited by the user.
    static func suggestAltText(for data: Data) async -> String? {
        await Task.detached(priority: .userInitiated) {
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(data: data, options: [:])
            guard (try? handler.perform([request])) != nil else { return nil }
            let labels = (request.results ?? [])
                .filter { $0.confidence > 0.2 }
                .prefix(3)
                .map { $0.identifier.replacingOccurrences(of: "_", with: " ") }
            guard !labels.isEmpty else { return nil }
            return "Image showing \(labels.joined(separator: ", "))"
        }.value
    }
}
