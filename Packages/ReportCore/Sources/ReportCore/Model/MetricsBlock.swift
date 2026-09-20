import Foundation

/// How a metrics block is laid out.
public enum MetricsLayout: String, Codable, CaseIterable, Sendable {
    /// Large-number KPI tiles, best for 2 to 6 headline numbers.
    case tiles
    /// A semantic table, best for longer lists.
    case table

    public var label: String {
        switch self {
        case .tiles: "Tiles"
        case .table: "Table"
        }
    }
}

/// A group of KPIs.
public struct MetricsBlock: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var heading: String
    public var metrics: [Metric]
    public var layout: MetricsLayout

    public init(id: UUID = UUID(), heading: String = "Key metrics", metrics: [Metric] = [], layout: MetricsLayout = .tiles) {
        self.id = id
        self.heading = heading
        self.metrics = metrics
        self.layout = layout
    }

    public var isEmpty: Bool {
        metrics.isEmpty
    }
}

/// One KPI: a label, a display value and an optional change indicator.
public struct Metric: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var label: String
    /// The value exactly as it should be displayed, e.g. "87%", "$1.2M", "42".
    public var value: String
    public var change: MetricChange?
    /// Optional history used for a sparkline. Oldest first.
    public var trend: [Double]

    public init(id: UUID = UUID(), label: String, value: String, change: MetricChange? = nil, trend: [Double] = []) {
        self.id = id
        self.label = label
        self.value = value
        self.change = change
        self.trend = trend
    }

    /// A screen-reader friendly sentence for the whole metric.
    public var accessibleDescription: String {
        var parts = ["\(label): \(value)"]
        if let change {
            parts.append(change.accessibleDescription)
        }
        return parts.joined(separator: ", ")
    }
}

/// Change of a metric versus its previous value.
///
/// Direction and sentiment are separate: a drop in "open bugs" is a
/// downward direction with positive sentiment.
public struct MetricChange: Codable, Hashable, Sendable {
    public enum Direction: String, Codable, CaseIterable, Sendable {
        case up, down, flat

        public var glyph: String {
            switch self {
            case .up: "▲"
            case .down: "▼"
            case .flat: "▬"
            }
        }

        public var word: String {
            switch self {
            case .up: "up"
            case .down: "down"
            case .flat: "unchanged"
            }
        }
    }

    public enum Sentiment: String, Codable, CaseIterable, Sendable {
        case positive, negative, neutral

        public var label: String {
            switch self {
            case .positive: "Positive"
            case .negative: "Negative"
            case .neutral: "Neutral"
            }
        }
    }

    public var direction: Direction
    public var sentiment: Sentiment
    /// Magnitude as it should be displayed, e.g. "5.2%", "3 pts", "12".
    public var text: String

    public init(direction: Direction, sentiment: Sentiment = .neutral, text: String) {
        self.direction = direction
        self.sentiment = sentiment
        self.text = text
    }

    /// Glyph plus text, e.g. "▲ 5.2%". Used by visual renderers.
    public var display: String {
        text.isEmpty ? direction.glyph : "\(direction.glyph) \(text)"
    }

    /// Words only, e.g. "up 5.2%, positive". Used for screen readers.
    public var accessibleDescription: String {
        let magnitude = text.isEmpty ? direction.word : "\(direction.word) \(text)"
        switch sentiment {
        case .neutral: return magnitude
        case .positive, .negative: return "\(magnitude), \(sentiment.label.lowercased())"
        }
    }

    public var flippedSentiment: MetricChange {
        var copy = self
        switch sentiment {
        case .positive: copy.sentiment = .negative
        case .negative: copy.sentiment = .positive
        case .neutral: break
        }
        return copy
    }
}
