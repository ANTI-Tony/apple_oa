import Foundation

/// Text size of a card. "Large" and "Extra Large" are large-print editions for
/// readers with low vision; every renderer scales its type by `scale`.
public enum CardTextSize: String, Codable, CaseIterable, Identifiable, Sendable {
    case standard
    case large
    case extraLarge = "extra_large"

    public var id: String {
        rawValue
    }

    public var scale: Double {
        switch self {
        case .standard: 1.0
        case .large: 1.2
        case .extraLarge: 1.4
        }
    }

    public var label: String {
        switch self {
        case .standard: "Standard"
        case .large: "Large"
        case .extraLarge: "Extra Large"
        }
    }
}
