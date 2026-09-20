import Foundation

/// Colours and shape of a rendered card.
///
/// Themes are data, not code: they serialise with the card so an export made
/// on one machine renders identically on another. Every built-in theme is
/// verified by `AccessibilityLinter` tests to meet WCAG AA contrast.
public struct CardTheme: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var isDark: Bool
    public var background: HexColor
    /// Background of tiles and other raised surfaces.
    public var surface: HexColor
    public var text: HexColor
    public var secondaryText: HexColor
    public var accent: HexColor
    public var border: HexColor
    public var cornerRadius: Double
    /// CSS font stack for HTML output.
    public var fontFamily: String

    public init(
        id: String,
        name: String,
        isDark: Bool,
        background: HexColor,
        surface: HexColor,
        text: HexColor,
        secondaryText: HexColor,
        accent: HexColor,
        border: HexColor,
        cornerRadius: Double = 12,
        fontFamily: String = CardTheme.systemFontStack
    ) {
        self.id = id
        self.name = name
        self.isDark = isDark
        self.background = background
        self.surface = surface
        self.text = text
        self.secondaryText = secondaryText
        self.accent = accent
        self.border = border
        self.cornerRadius = cornerRadius
        self.fontFamily = fontFamily
    }

    public static let systemFontStack =
        "-apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', Helvetica, Arial, sans-serif"

    // MARK: Built-in themes

    public static let light = CardTheme(
        id: "light",
        name: "Light",
        isDark: false,
        background: "#FFFFFF",
        surface: "#F5F5F7",
        text: "#1D1D1F",
        secondaryText: "#6E6E73",
        accent: "#0066CC",
        border: "#D2D2D7",
        cornerRadius: 16
    )

    public static let dark = CardTheme(
        id: "dark",
        name: "Dark",
        isDark: true,
        background: "#1C1C1E",
        surface: "#2C2C2E",
        text: "#F5F5F7",
        secondaryText: "#A1A1A6",
        accent: "#409CFF",
        border: "#3A3A3C",
        cornerRadius: 16
    )

    /// Warm off-white with brown-black text, in the spirit of a paper notebook.
    public static let paper = CardTheme(
        id: "paper",
        name: "Paper",
        isDark: false,
        background: "#FBF8F1",
        surface: "#F2EDE1",
        text: "#2B2621",
        secondaryText: "#675E53",
        accent: "#8A4B12",
        border: "#E0D7C5",
        cornerRadius: 16
    )

    public static let highContrast = CardTheme(
        id: "high_contrast",
        name: "High Contrast",
        isDark: false,
        background: "#FFFFFF",
        surface: "#FFFFFF",
        text: "#000000",
        secondaryText: "#2B2B2B",
        accent: "#0000B8",
        border: "#000000",
        cornerRadius: 8
    )

    public static let builtIn: [CardTheme] = [.light, .dark, .paper, .highContrast]

    public static func builtIn(id: String) -> CardTheme? {
        builtIn.first { $0.id == id }
    }

    // MARK: Semantic colours

    /// Colour of the small status indicator next to the status label.
    ///
    /// These are Apple's increased-contrast system colours, so the indicator
    /// keeps at least 3:1 against the card background (WCAG 1.4.11). The label
    /// itself is set in the text colour; colour never carries the status alone.
    public func statusColor(for status: ReportStatus) -> HexColor {
        if isDark {
            switch status {
            case .onTrack: return "#30DB5B"
            case .atRisk: return "#FFB340"
            case .offTrack: return "#FF6961"
            case .completed: return "#409CFF"
            case .notStarted: return "#AEAEB2"
            }
        } else {
            switch status {
            case .onTrack: return "#248A3D"
            case .atRisk: return "#C93400"
            case .offTrack: return "#D70015"
            case .completed: return "#0040DD"
            case .notStarted: return "#6C6C70"
            }
        }
    }

    /// Text colour for a metric change indicator, on the `surface` colour.
    public func changeColor(for sentiment: MetricChange.Sentiment) -> HexColor {
        if isDark {
            switch sentiment {
            case .positive: return "#30DB5B"
            case .negative: return "#FF6961"
            case .neutral: return secondaryText
            }
        } else {
            switch sentiment {
            case .positive: return "#1A6B30"
            case .negative: return "#B4121B"
            case .neutral: return secondaryText
            }
        }
    }
}
