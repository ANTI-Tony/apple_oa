import Foundation

/// A status report as a language model returns it. Nothing in here is
/// trusted: `CardDraftParser` validates and bounds every field before it
/// becomes a card.
public struct CardDraft: Codable, Equatable, Sendable {
    public struct DraftMetric: Codable, Equatable, Sendable {
        public var label: String
        public var value: String
        public var change: String?

        public init(label: String, value: String, change: String? = nil) {
            self.label = label
            self.value = value
            self.change = change
        }
    }

    public var title: String?
    public var subtitle: String?
    public var status: String?
    public var summary: String?
    public var highlights: [String]?
    public var metrics: [DraftMetric]?
    public var risks: [String]?
    public var nextSteps: [String]?

    public init(
        title: String? = nil,
        subtitle: String? = nil,
        status: String? = nil,
        summary: String? = nil,
        highlights: [String]? = nil,
        metrics: [DraftMetric]? = nil,
        risks: [String]? = nil,
        nextSteps: [String]? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.status = status
        self.summary = summary
        self.highlights = highlights
        self.metrics = metrics
        self.risks = risks
        self.nextSteps = nextSteps
    }
}

public enum CardDraftError: Error, Equatable, LocalizedError {
    case noJSONFound
    case invalidJSON(String)
    case empty

    public var errorDescription: String? {
        switch self {
        case .noJSONFound: "The reply did not contain a report."
        case let .invalidJSON(detail): "The reply was not valid JSON (\(detail))."
        case .empty: "The reply contained no usable content."
        }
    }
}

/// Turns a model's reply into a card, defensively.
///
/// - Accepts JSON wrapped in prose or code fences, and snake_case or camelCase keys.
/// - Bounds every string and list, so a runaway reply cannot produce a runaway card.
/// - Maps loose status words ("green", "At Risk") onto `ReportStatus`.
/// - Reuses `MetricsParser` for changes, so "+5%" gets the same direction and
///   good/bad inference as pasted data.
public enum CardDraftParser {
    public static let maxItemsPerList = 6
    public static let maxItemLength = 200
    public static let maxTitleLength = 80

    public static func parse(_ reply: String) throws -> CardDraft {
        guard let start = reply.firstIndex(of: "{"), let end = reply.lastIndex(of: "}"), start < end else {
            throw CardDraftError.noJSONFound
        }
        let json = String(reply[start ... end])
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(CardDraft.self, from: Data(json.utf8))
        } catch {
            throw CardDraftError.invalidJSON(String(describing: error).prefix(120).description)
        }
    }

    public static func makeCard(
        from draft: CardDraft,
        theme: CardTheme = .light,
        author: String = "",
        now: Date = Date()
    ) throws -> SnippetCard {
        var blocks: [Block] = []
        if let summary = clean(draft.summary, limit: 400) {
            blocks.append(.text(TextBlock(heading: "Summary", body: summary)))
        }
        if let items = bullets(draft.highlights) {
            blocks.append(.text(TextBlock(heading: "Highlights", body: items)))
        }
        let metrics = (draft.metrics ?? []).prefix(maxItemsPerList).compactMap(metric(from:))
        if !metrics.isEmpty {
            blocks.append(.metrics(MetricsBlock(heading: "Key metrics", metrics: metrics)))
        }
        if let items = bullets(draft.risks) {
            blocks.append(.text(TextBlock(heading: "Risks and asks", body: items)))
        }
        if let items = bullets(draft.nextSteps) {
            blocks.append(.text(TextBlock(heading: "Next steps", body: items)))
        }
        guard !blocks.isEmpty else { throw CardDraftError.empty }

        return SnippetCard(
            title: clean(draft.title, limit: maxTitleLength) ?? "Project update",
            subtitle: clean(draft.subtitle, limit: maxTitleLength) ?? "",
            author: author,
            status: status(from: draft.status),
            blocks: blocks,
            theme: theme,
            createdAt: now,
            updatedAt: now
        )
    }

    // MARK: Field hygiene

    static func clean(_ text: String?, limit: Int) -> String? {
        guard let text else { return nil }
        let collapsed = text
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return nil }
        return collapsed.count > limit ? String(collapsed.prefix(limit - 1)) + "…" : collapsed
    }

    static func bullets(_ items: [String]?) -> String? {
        let cleaned = (items ?? [])
            .compactMap { clean($0, limit: maxItemLength) }
            .map { item -> String in
                // The model was told not to add bullet characters; strip them if it did.
                var text = item
                for prefix in ["• ", "- ", "* "] where text.hasPrefix(prefix) {
                    text = String(text.dropFirst(prefix.count))
                }
                return text.replacingOccurrences(of: "\n", with: " ")
            }
            .filter { !$0.isEmpty }
            .prefix(maxItemsPerList)
        guard !cleaned.isEmpty else { return nil }
        return cleaned.map { "• \($0)" }.joined(separator: "\n")
    }

    static func metric(from draft: CardDraft.DraftMetric) -> Metric? {
        guard let label = clean(draft.label, limit: 60), let value = clean(draft.value, limit: 24) else { return nil }
        return MetricsParser.makeMetric(label: label, value: value, previous: nil, change: clean(draft.change, limit: 16), trend: [])
    }

    static func status(from text: String?) -> ReportStatus {
        let key = (text ?? "").lowercased().filter { $0.isLetter }
        switch key {
        case "ontrack", "green", "good", "healthy": return .onTrack
        case "atrisk", "amber", "yellow", "orange", "risk", "caution": return .atRisk
        case "offtrack", "red", "blocked", "delayed", "late": return .offTrack
        case "completed", "complete", "done", "closed", "shipped": return .completed
        case "notstarted", "planned", "pending": return .notStarted
        default: return .onTrack
        }
    }
}
