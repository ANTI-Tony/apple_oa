import Foundation

/// Overall health of the project the card reports on.
///
/// Every status carries a text label and a distinct glyph in addition to a
/// colour, so status is never conveyed by colour alone (WCAG 1.4.1).
public enum ReportStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case onTrack = "on_track"
    case atRisk = "at_risk"
    case offTrack = "off_track"
    case completed
    case notStarted = "not_started"

    public var id: String {
        rawValue
    }

    public var label: String {
        switch self {
        case .onTrack: "On track"
        case .atRisk: "At risk"
        case .offTrack: "Off track"
        case .completed: "Completed"
        case .notStarted: "Not started"
        }
    }

    /// Shape glyph used next to the label. Shapes differ per status so the
    /// meaning survives greyscale printing and colour-vision deficiency.
    public var glyph: String {
        switch self {
        case .onTrack: "●"
        case .atRisk: "▲"
        case .offTrack: "■"
        case .completed: "✔"
        case .notStarted: "○"
        }
    }

    /// SF Symbol name for platform UI.
    public var symbolName: String {
        switch self {
        case .onTrack: "checkmark.circle.fill"
        case .atRisk: "exclamationmark.triangle.fill"
        case .offTrack: "xmark.octagon.fill"
        case .completed: "flag.checkered"
        case .notStarted: "circle.dashed"
        }
    }
}
