import Foundation

/// An sRGB colour stored as 8-bit channels and serialised as `#RRGGBB`.
///
/// Kept independent of AppKit/UIKit so the core package stays portable and
/// so WCAG contrast maths can run in unit tests without a graphics context.
public struct HexColor: Hashable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Accepts `#RRGGBB`, `RRGGBB`, `#RGB` or `RGB`.
    public init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") {
            text.removeFirst()
        }
        if text.count == 3 {
            text = text.map { "\($0)\($0)" }.joined()
        }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        red = UInt8((value >> 16) & 0xFF)
        green = UInt8((value >> 8) & 0xFF)
        blue = UInt8(value & 0xFF)
    }

    public var hexString: String {
        String(format: "#%02X%02X%02X", red, green, blue)
    }

    /// Channels as 0...1 doubles.
    public var components: (red: Double, green: Double, blue: Double) {
        (Double(red) / 255, Double(green) / 255, Double(blue) / 255)
    }

    // MARK: WCAG 2.x

    /// Relative luminance per WCAG 2.x, 0 (black) to 1 (white).
    public var relativeLuminance: Double {
        func linearise(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        let rgb = components
        return 0.2126 * linearise(rgb.red) + 0.7152 * linearise(rgb.green) + 0.0722 * linearise(rgb.blue)
    }

    /// Contrast ratio between two colours, from 1 to 21.
    public static func contrastRatio(_ first: HexColor, _ second: HexColor) -> Double {
        let lighter = max(first.relativeLuminance, second.relativeLuminance)
        let darker = min(first.relativeLuminance, second.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    public func contrastRatio(against other: HexColor) -> Double {
        Self.contrastRatio(self, other)
    }

    public static let white = HexColor(red: 255, green: 255, blue: 255)
    public static let black = HexColor(red: 0, green: 0, blue: 0)
}

extension HexColor: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let color = HexColor(hex: text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid hex colour \(text)")
        }
        self = color
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hexString)
    }
}

extension HexColor: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        guard let color = HexColor(hex: value) else {
            preconditionFailure("Invalid hex colour literal \(value)")
        }
        self = color
    }
}

/// WCAG 2.1 contrast thresholds.
public enum ContrastLevel {
    /// 1.4.3 Contrast (Minimum) for normal text.
    public static let aaNormalText = 4.5
    /// 1.4.3 for large text and 1.4.11 for UI components and graphics.
    public static let aaLargeText = 3.0
    /// 1.4.6 Contrast (Enhanced).
    public static let aaaNormalText = 7.0
}
