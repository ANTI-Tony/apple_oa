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
        border: "#D2D2D7"
    )

    public static let dark = CardTheme(
        id: "dark",
        name: "Dark",
        isDark: true,
        background: "#1D1D1F",
        surface: "#2C2C2E",
        text: "#F5F5F7",
        secondaryText: "#A1A1A6",
        accent: "#2997FF",
        border: "#3A3A3C"
    )

    public static let highContrast = CardTheme(
        id: "high_contrast",
        name: "High contrast",
        isDark: false,
        background: "#FFFFFF",
        surface: "#FFFFFF",
        text: "#000000",
        secondaryText: "#2B2B2B",
        accent: "#0000B8",
        border: "#000000",
        cornerRadius: 6
    )

    public static let ocean = CardTheme(
        id: "ocean",
        name: "Ocean",
        isDark: false,
        background: "#F0F6FF",
        surface: "#FFFFFF",
        text: "#0B1F33",
        secondaryText: "#3F5A73",
        accent: "#005A9C",
        border: "#BFD7EE"
    )

    public static let builtIn: [CardTheme] = [.light, .dark, .highContrast, .ocean]

    public static func builtIn(id: String) -> CardTheme? {
        builtIn.first { $0.id == id }
    }

    // MARK: Semantic colours

    /// Foreground and background pair for a status pill. Pairs are chosen per
    /// light/dark family so text contrast stays above 4.5:1.
    public func statusColors(for status: ReportStatus) -> (foreground: HexColor, background: HexColor) {
        if isDark {
            switch status {
            case .onTrack: return ("#B7F0C4", "#14532D")
            case .atRisk: return ("#FDE68A", "#5A3E00")
            case .offTrack: return ("#FECACA", "#7F1D1D")
            case .completed: return ("#BFDBFE", "#1E3A8A")
            case .notStarted: return ("#E5E7EB", "#3F3F46")
            }
        } else {
            switch status {
            case .onTrack: return ("#166534", "#DCFCE7")
            case .atRisk: return ("#7A4A00", "#FEF3C7")
            case .offTrack: return ("#991B1B", "#FEE2E2")
            case .completed: return ("#1E40AF", "#DBEAFE")
            case .notStarted: return ("#374151", "#F3F4F6")
            }
        }
    }

    /// Text colour for a metric change indicator, on the `surface` colour.
    public func changeColor(for sentiment: MetricChange.Sentiment) -> HexColor {
        if isDark {
            switch sentiment {
            case .positive: return "#6EE7A0"
            case .negative: return "#FCA5A5"
            case .neutral: return secondaryText
            }
        } else {
            switch sentiment {
            case .positive: return "#15803D"
            case .negative: return "#B91C1C"
            case .neutral: return secondaryText
            }
        }
    }
}
