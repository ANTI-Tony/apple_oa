import Foundation

/// What pasted or dropped text most likely is.
public enum DetectedContent: Hashable, Sendable {
    case metrics(MetricsParseResult)
    case text(String)
}

/// Classifies free text so "smart paste" can offer the right block type.
public enum ContentDetector {
    /// Minimum share of lines that must parse as metrics before text is
    /// treated as metric data. Prose with one "Note: something" line stays prose.
    public static let minimumCoverage = 0.6

    public static func detect(_ text: String) -> DetectedContent {
        guard let result = MetricsParser.parse(text) else { return .text(text) }
        switch result.format {
        case .json:
            return .metrics(result)
        case .delimited, .keyValue:
            let plausible = result.metrics.count >= 2 && result.coverage >= minimumCoverage
                && result.metrics.allSatisfy { $0.label.count <= 60 }
            return plausible ? .metrics(result) : .text(text)
        }
    }
}
