import Foundation

/// Result of turning pasted text into metrics.
public struct MetricsParseResult: Hashable, Sendable {
    public enum Format: String, Sendable {
        case delimited
        case keyValue
        case json
    }

    public var metrics: [Metric]
    public var format: Format
    /// Share of non-empty input lines that produced a metric, 0...1.
    public var coverage: Double
    public var warnings: [String]

    public init(metrics: [Metric], format: Format, coverage: Double, warnings: [String] = []) {
        self.metrics = metrics
        self.format = format
        self.coverage = coverage
        self.warnings = warnings
    }
}

/// Turns loosely structured text into `Metric` values.
///
/// Accepted shapes, in the order they are tried:
/// 1. JSON: an array of objects (`[{"label": "Velocity", "value": 42}]`) or
///    an object of label/value pairs.
/// 2. Delimited rows (CSV, TSV as pasted from Numbers or Excel, `;` or `|`),
///    with or without a header row. Recognised header names: label/name/metric,
///    value/current/actual, previous/prior/last, change/delta, trend/history.
/// 3. `Label: value` lines, optionally followed by a change in parentheses,
///    e.g. `Velocity: 42 (+5%)`.
///
/// Sentiment of a change is inferred from the label: words like "bugs",
/// "latency" or "cost" flip the meaning so a decrease reads as positive.
public enum MetricsParser {
    /// - Parameter allowBareNumbers: also accept `Label 42` lines with no
    ///   separator. Off by default because prose often ends in a number; on
    ///   for OCR output, where the user reviews the result before inserting.
    public static func parse(_ text: String, allowBareNumbers: Bool = false) -> MetricsParseResult? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("[") || trimmed.hasPrefix("{"), let result = parseJSON(trimmed) {
            return result
        }
        let lines = trimmed.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }

        if let delimiter = detectDelimiter(in: lines), let result = parseDelimited(lines, delimiter: delimiter) {
            return result
        }
        return parseKeyValue(lines, allowBareNumbers: allowBareNumbers)
    }

    /// Joins OCR-style output where a label and its value land on separate
    /// lines ("Velocity" / "42") into "Velocity: 42" lines. Lines that already
    /// carry a value are passed through unchanged.
    public static func pairLabelValueLines(_ lines: [String]) -> [String] {
        var output: [String] = []
        var pendingLabel: String?
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            let isBareNumber = NumberParsing.parse(line) != nil
            if isBareNumber, let label = pendingLabel {
                output.append("\(label): \(line)")
                pendingLabel = nil
            } else if isBareNumber {
                output.append(line)
            } else {
                if let label = pendingLabel {
                    output.append(label)
                }
                pendingLabel = line
            }
        }
        if let pendingLabel {
            output.append(pendingLabel)
        }
        return output
    }

    // MARK: Column roles

    enum Role: Sendable {
        case label, value, previous, change, trend, unit, ignored
    }

    static func role(forHeader header: String) -> Role {
        let key = header.lowercased().filter { $0.isLetter || $0.isNumber }
        switch key {
        case "label", "name", "metric", "kpi", "item", "key", "measure", "indicator":
            return .label
        case "value", "current", "actual", "now", "thisweek", "thisperiod", "result", "count", "total", "amount", "latest":
            return .value
        case "previous", "prior", "last", "baseline", "lastweek", "lastperiod", "before", "prev":
            return .previous
        case "change", "delta", "diff", "difference", "vs", "vsprevious", "vslastweek", "changepct", "change%":
            return .change
        case "trend", "history", "sparkline", "series", "values":
            return .trend
        case "unit", "units":
            return .unit
        default:
            return .ignored
        }
    }

    /// Cells of one row, grouped by role.
    struct RowFields {
        var label = ""
        var value: String?
        var previous: String?
        var change: String?
        var unit = ""
        var trend: [Double] = []

        init() {}

        init(row: [String], roles: [Role]) {
            for (index, cell) in row.enumerated() where index < roles.count {
                switch roles[index] {
                case .label: label = cell
                case .value: value = cell
                case .previous: previous = cell
                case .change: change = cell
                case .unit: unit = cell
                case .trend: trend += MetricsParser.parseSeries(cell)
                case .ignored: break
                }
            }
        }

        /// Builds the metric, or nil when there is nothing to show.
        func metric() -> Metric? {
            var display = value
            if display == nil, let last = trend.last {
                display = NumberParsing.format(last)
            }
            guard let display, !display.isEmpty else { return nil }
            let withUnit = unit.isEmpty || display.contains(unit) ? display : "\(display) \(unit)"
            return MetricsParser.makeMetric(label: label, value: withUnit, previous: previous, change: change, trend: trend)
        }
    }

    // MARK: Delimited

    static func detectDelimiter(in lines: [String]) -> Character? {
        let candidates: [Character] = ["\t", "|", ";", ","]
        let sample = lines.prefix(5)
        for delimiter in candidates {
            let counts = sample.map { line in line.filter { $0 == delimiter }.count }
            let linesWithDelimiter = counts.filter { $0 > 0 }.count
            if linesWithDelimiter * 2 >= sample.count, counts.first ?? 0 > 0 {
                return delimiter
            }
        }
        return nil
    }

    static func splitRow(_ line: String, delimiter: Character) -> [String] {
        guard delimiter == "," || delimiter == ";" else {
            return line.split(separator: delimiter, omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
        }
        // RFC 4180-style quoting for comma/semicolon separated rows.
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = line.makeIterator()
        var pending: Character? = iterator.next()
        while let character = pending {
            pending = iterator.next()
            if character == "\"" {
                if inQuotes, pending == "\"" {
                    current.append("\"")
                    pending = iterator.next()
                } else {
                    inQuotes.toggle()
                }
            } else if character == delimiter, !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        fields.append(current)
        return fields.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Decides whether the first row is a header and what each column means.
    static func resolveRoles(rows: [[String]]) -> (roles: [Role], dataRows: [[String]])? {
        let firstRoles = rows[0].map(role(forHeader:))
        let firstRowIsText = rows[0].dropFirst().allSatisfy { NumberParsing.parse($0) == nil }
        let secondRowHasNumbers = rows.count > 1 && rows[1].dropFirst().contains { NumberParsing.parse($0) != nil }
        let hasHeader = firstRoles.contains(.value) || firstRoles.contains(.label) || (firstRowIsText && secondRowHasNumbers)

        if hasHeader {
            var roles = firstRoles
            if !roles.contains(.label) {
                roles[0] = .label
            }
            if !roles.contains(.value), let index = roles.indices.first(where: { roles[$0] == .ignored && $0 > 0 }) {
                roles[index] = .value
            }
            guard roles.contains(.value) || roles.contains(.trend) else { return nil }
            return (roles, Array(rows.dropFirst()))
        }

        let width = rows.map(\.count).max() ?? 2
        var roles = Array(repeating: Role.ignored, count: width)
        roles[0] = .label
        let allNumeric = rows.allSatisfy { $0.dropFirst().allSatisfy { NumberParsing.parse($0) != nil } }
        if width >= 5, allNumeric {
            // Label followed by a series: treat the series as the trend, last point as value.
            for index in 1 ..< width {
                roles[index] = .trend
            }
        } else {
            roles[1] = .value
            if width >= 3 {
                roles[2] = .previous
            }
        }
        return (roles, rows)
    }

    static func parseDelimited(_ lines: [String], delimiter: Character) -> MetricsParseResult? {
        let rows = lines.map { splitRow($0, delimiter: delimiter) }.filter { $0.count >= 2 }
        guard !rows.isEmpty, let resolved = resolveRoles(rows: rows) else { return nil }

        var metrics: [Metric] = []
        var warnings: [String] = []
        for row in resolved.dataRows {
            let fields = RowFields(row: row, roles: resolved.roles)
            if let metric = fields.metric() {
                metrics.append(metric)
            } else if !fields.label.isEmpty {
                warnings.append("Skipped \"\(fields.label)\": no value found.")
            }
        }
        guard !metrics.isEmpty else { return nil }
        return MetricsParseResult(
            metrics: metrics,
            format: .delimited,
            coverage: Double(metrics.count) / Double(max(lines.count, 1)),
            warnings: warnings
        )
    }

    static func parseSeries(_ cell: String) -> [Double] {
        cell.split(whereSeparator: { " ;|/".contains($0) })
            .compactMap { NumberParsing.parse(String($0))?.value }
    }

    // MARK: Key/value

    static func parseKeyValue(_ lines: [String], allowBareNumbers: Bool = false) -> MetricsParseResult? {
        let pattern = #"^([^:=]{1,80}?)\s*[:=]\s*(.+)$"#
        let barePattern = #"^(.{1,60}?)\s+([+\-−]?[$€£¥]?[0-9][0-9.,]*\s?(?:%|[kKmMbB])?)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let bareRegex = try? NSRegularExpression(pattern: barePattern) else { return nil }
        var metrics: [Metric] = []
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            var match = regex.firstMatch(in: line, range: range)
            if match == nil, allowBareNumbers {
                match = bareRegex.firstMatch(in: line, range: range)
            }
            guard let match,
                  let labelRange = Range(match.range(at: 1), in: line),
                  let restRange = Range(match.range(at: 2), in: line) else { continue }
            let label = String(line[labelRange]).trimmingCharacters(in: .whitespaces)
            let rest = String(line[restRange]).trimmingCharacters(in: .whitespaces)
            let (value, change) = splitTrailingChange(rest)
            guard !value.isEmpty else { continue }
            metrics.append(makeMetric(label: label, value: value, previous: nil, change: change, trend: []))
        }
        guard !metrics.isEmpty else { return nil }
        return MetricsParseResult(
            metrics: metrics,
            format: .keyValue,
            coverage: Double(metrics.count) / Double(lines.count)
        )
    }

    /// Splits "42 (+5%)" or "42 ▲5%" into ("42", "+5%").
    static func splitTrailingChange(_ text: String) -> (value: String, change: String?) {
        let patterns = [
            #"^(.*?)\s*\(\s*([+\-−▲▼↑↓]\s*[0-9][0-9.,]*\s*%?(?:\s*pts?)?)\s*\)$"#,
            #"^(.*?)\s+([+\-−▲▼↑↓]\s*[0-9][0-9.,]*\s*%?(?:\s*pts?)?)$"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let valueRange = Range(match.range(at: 1), in: text),
                  let changeRange = Range(match.range(at: 2), in: text) else { continue }
            let value = String(text[valueRange]).trimmingCharacters(in: .whitespaces)
            if !value.isEmpty {
                return (value, String(text[changeRange]))
            }
        }
        return (text, nil)
    }

    // MARK: JSON

    static func parseJSON(_ text: String) -> MetricsParseResult? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        var metrics: [Metric] = []
        if let array = object as? [[String: Any]] {
            metrics = array.compactMap(metric(fromJSONObject:))
        } else if let dictionary = object as? [String: Any] {
            for key in dictionary.keys.sorted() {
                guard let raw = dictionary[key], !(raw is [Any]), !(raw is [String: Any]) else { continue }
                metrics.append(makeMetric(label: key, value: stringValue(raw), previous: nil, change: nil, trend: []))
            }
        }
        guard !metrics.isEmpty else { return nil }
        return MetricsParseResult(metrics: metrics, format: .json, coverage: 1)
    }

    private static func metric(fromJSONObject item: [String: Any]) -> Metric? {
        var fields = RowFields()
        for (key, raw) in item {
            switch role(forHeader: key) {
            case .label: fields.label = stringValue(raw)
            case .value: fields.value = stringValue(raw)
            case .previous: fields.previous = stringValue(raw)
            case .change: fields.change = stringValue(raw)
            case .trend:
                if let numbers = raw as? [Any] {
                    fields.trend = numbers.compactMap { NumberParsing.parse(stringValue($0))?.value }
                }
            case .unit: fields.unit = stringValue(raw)
            case .ignored: break
            }
        }
        return fields.metric()
    }

    private static func stringValue(_ raw: Any) -> String {
        switch raw {
        case let string as String: return string
        case let number as NSNumber: return number.stringValue
        default: return "\(raw)"
        }
    }

    // MARK: Metric assembly

    static func makeMetric(label: String, value: String, previous: String?, change: String?, trend: [Double]) -> Metric {
        var metric = Metric(label: label, value: value, trend: trend)
        if let change, let parsed = parseChange(change) {
            metric.change = parsed
        } else if let previous, let computed = computeChange(value: value, previous: previous) {
            metric.change = computed
        }
        if var change = metric.change {
            change.sentiment = SentimentHeuristics.sentiment(for: change.direction, label: label)
            metric.change = change
        }
        return metric
    }

    private static let directionGlyphs: [(glyph: String, direction: MetricChange.Direction)] = [
        ("▲", .up), ("↑", .up), ("▼", .down), ("↓", .down), ("▬", .flat),
    ]

    /// Parses a change typed by a user or found in a "change" column:
    /// "+5%", "-3", "▲ 2 pts", "0". Sentiment is left neutral; callers apply
    /// `SentimentHeuristics` with the metric's label.
    public static func parseChange(_ text: String) -> MetricChange? {
        var cleaned = text.trimmingCharacters(in: .whitespaces)
        var direction: MetricChange.Direction?
        for entry in directionGlyphs where cleaned.hasPrefix(entry.glyph) {
            direction = entry.direction
            cleaned = String(cleaned.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        guard let parsed = NumberParsing.parse(cleaned) else {
            if let direction {
                return MetricChange(direction: direction, text: cleaned)
            }
            return nil
        }
        let resolvedDirection = direction ?? (parsed.value > 0 ? .up : parsed.value < 0 ? .down : .flat)
        let magnitude = NumberParsing.format(parsed.value)
        let lowered = cleaned.lowercased()
        let suffix = parsed.isPercent ? "%" : (lowered.hasSuffix("pts") || lowered.hasSuffix("pt") ? " pts" : "")
        return MetricChange(direction: resolvedDirection, text: magnitude + suffix)
    }

    static func computeChange(value: String, previous: String) -> MetricChange? {
        guard let current = NumberParsing.parse(value), let prior = NumberParsing.parse(previous) else { return nil }
        let difference = current.value - prior.value
        if abs(difference) < 1e-9 {
            return MetricChange(direction: .flat, text: "")
        }
        let direction: MetricChange.Direction = difference > 0 ? .up : .down
        if current.isPercent || prior.isPercent {
            return MetricChange(direction: direction, text: "\(NumberParsing.format(difference)) pts")
        }
        guard prior.value != 0 else {
            return MetricChange(direction: direction, text: NumberParsing.format(difference))
        }
        let percent = difference / abs(prior.value) * 100
        return MetricChange(direction: direction, text: "\(NumberParsing.format(percent))%")
    }
}

/// Decides whether a movement is good or bad news from the metric's label.
public enum SentimentHeuristics {
    /// Labels containing these words are "lower is better".
    public static let lowerIsBetterTerms: [String] = [
        "bug", "defect", "incident", "error", "latency", "cost", "spend", "churn", "risk", "debt",
        "downtime", "delay", "escalation", "outage", "blocker", "overdue", "crash", "failure", "mttr",
        "p0", "p1", "sev1", "sev2", "regression", "vulnerabilit", "complaint", "backlog", "open issue",
        "time to", "wait", "queue", "lead time", "cycle time", "burn rate", "attrition",
    ]

    public static func lowerIsBetter(label: String) -> Bool {
        let lowered = label.lowercased()
        return lowerIsBetterTerms.contains { lowered.contains($0) }
    }

    public static func sentiment(for direction: MetricChange.Direction, label: String) -> MetricChange.Sentiment {
        switch direction {
        case .flat: return .neutral
        case .up: return lowerIsBetter(label: label) ? .negative : .positive
        case .down: return lowerIsBetter(label: label) ? .positive : .negative
        }
    }
}
