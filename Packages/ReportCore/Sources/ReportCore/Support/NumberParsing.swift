import Foundation

/// Parses human-entered numbers such as "1,234.5", "87%", "$1.2M" or "−3".
public enum NumberParsing {
    public struct Parsed: Equatable, Sendable {
        public var value: Double
        public var isPercent: Bool
    }

    private static let placeholders: Set<String> = ["", "-", "—", "–", "n/a", "na", "none", "null", "tbd"]

    public static func parse(_ raw: String) -> Parsed? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if placeholders.contains(text) {
            return nil
        }

        // Unicode minus and parenthesised negatives, e.g. "(1,200)".
        text = text.replacingOccurrences(of: "−", with: "-")
        var negative = false
        if text.hasPrefix("(") && text.hasSuffix(")") {
            negative = true
            text = String(text.dropFirst().dropLast())
        }
        if text.hasPrefix("+") {
            text.removeFirst()
        }
        if text.hasPrefix("-") {
            negative.toggle()
            text.removeFirst()
        }

        let isPercent = text.hasSuffix("%")
        if isPercent {
            text.removeLast()
        }

        var multiplier = 1.0
        if let last = text.last, let factor = suffixMultiplier(last) {
            multiplier = factor
            text.removeLast()
        }

        text = text.filter { !"$€£¥₹,_ ".contains($0) }
        text = text.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, let value = Double(text) else { return nil }
        return Parsed(value: (negative ? -value : value) * multiplier, isPercent: isPercent)
    }

    private static func suffixMultiplier(_ character: Character) -> Double? {
        switch character {
        case "k": 1000
        case "m": 1_000_000
        case "b": 1_000_000_000
        default: nil
        }
    }

    /// Formats a magnitude compactly: 5.2, 12, 1234.
    public static func format(_ value: Double) -> String {
        let magnitude = abs(value)
        if magnitude < 10 {
            let rounded = (magnitude * 10).rounded() / 10
            return rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.1f", rounded)
        }
        return String(Int(magnitude.rounded()))
    }
}
