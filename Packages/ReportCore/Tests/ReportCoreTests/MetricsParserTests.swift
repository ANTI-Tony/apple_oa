import Foundation
import Testing
@testable import ReportCore

@Suite("MetricsParser")
struct MetricsParserTests {
    @Test("CSV with a header row and previous column computes percentage change")
    func csvWithHeader() throws {
        let result = try #require(MetricsParser.parse("""
        Metric,Current,Previous
        Velocity,42,40
        Open bugs,12,15
        "Cycle time, days",3.5,3.5
        """))
        #expect(result.format == .delimited)
        #expect(result.metrics.count == 3)

        let velocity = result.metrics[0]
        #expect(velocity.label == "Velocity")
        #expect(velocity.value == "42")
        #expect(velocity.change == MetricChange(direction: .up, sentiment: .positive, text: "5%"))

        let bugs = result.metrics[1]
        #expect(bugs.change?.direction == .down)
        #expect(bugs.change?.sentiment == .positive, "fewer bugs is good news")
        #expect(bugs.change?.text == "20%")

        let cycle = result.metrics[2]
        #expect(cycle.label == "Cycle time, days", "quoted commas survive")
        #expect(cycle.change?.direction == .flat)
    }

    @Test("TSV as pasted from a spreadsheet, no header, two columns")
    func tsvNoHeader() throws {
        let result = try #require(MetricsParser.parse("Velocity\t42\nCoverage\t81%\n"))
        #expect(result.format == .delimited)
        #expect(result.metrics.map(\.label) == ["Velocity", "Coverage"])
        #expect(result.metrics.map(\.value) == ["42", "81%"])
        #expect(result.metrics.allSatisfy { $0.change == nil })
    }

    @Test("Percent values report change in points, not percent of percent")
    func percentagePoints() throws {
        let result = try #require(MetricsParser.parse("name,value,previous\nCoverage,81%,79%"))
        #expect(result.metrics[0].change?.text == "2 pts")
    }

    @Test("A label followed by a numeric series becomes a trend")
    func trendSeries() throws {
        let result = try #require(MetricsParser.parse("Velocity,38,40,39,42,44"))
        let metric = result.metrics[0]
        #expect(metric.trend == [38, 40, 39, 42, 44])
        #expect(metric.value == "44")
    }

    @Test("Explicit trend column with space separated history")
    func trendColumn() throws {
        let result = try #require(MetricsParser.parse("metric,value,trend\nLatency,120ms,150 140 130 120"))
        #expect(result.metrics[0].trend == [150, 140, 130, 120])
        #expect(result.metrics[0].value == "120ms")
    }

    @Test("Key/value lines with a trailing change in parentheses")
    func keyValue() throws {
        let result = try #require(MetricsParser.parse("""
        Velocity: 42 (+5%)
        Open bugs = 12 (-3)
        Uptime: 99.9%
        """))
        #expect(result.format == .keyValue)
        #expect(result.metrics[0].value == "42")
        #expect(result.metrics[0].change == MetricChange(direction: .up, sentiment: .positive, text: "5%"))
        #expect(result.metrics[1].change == MetricChange(direction: .down, sentiment: .positive, text: "3"))
        #expect(result.metrics[2].value == "99.9%")
        #expect(result.metrics[2].change == nil)
    }

    @Test("JSON array and JSON object shapes")
    func json() throws {
        let array = try #require(MetricsParser.parse(#"[{"label":"Velocity","value":42,"previous":40},{"name":"Bugs","current":"12"}]"#))
        #expect(array.format == .json)
        #expect(array.metrics.map(\.label) == ["Velocity", "Bugs"])
        #expect(array.metrics[0].change?.text == "5%")

        let object = try #require(MetricsParser.parse(#"{"Velocity": 42, "Bugs": 12}"#))
        #expect(object.metrics.map(\.label) == ["Bugs", "Velocity"], "object keys are sorted for determinism")
    }

    @Test("Currency, thousands separators and magnitude suffixes parse")
    func numberParsing() {
        #expect(NumberParsing.parse("$1,234.50")?.value == 1234.5)
        #expect(NumberParsing.parse("1.2k")?.value == 1200)
        #expect(NumberParsing.parse("−3")?.value == -3)
        #expect(NumberParsing.parse("(200)")?.value == -200)
        #expect(NumberParsing.parse("87%") == NumberParsing.Parsed(value: 87, isPercent: true))
        #expect(NumberParsing.parse("n/a") == nil)
        #expect(NumberParsing.parse("Friday") == nil)
    }

    @Test("Prose is not mistaken for metrics")
    func proseIsText() {
        let prose = """
        We finished the migration this week. Note: the vendor call moved to Thursday.
        The team is confident about the release date.
        """
        guard case .text = ContentDetector.detect(prose) else {
            Issue.record("prose was classified as metrics")
            return
        }
    }

    @Test("Tabular paste is offered as metrics")
    func tableIsMetrics() {
        guard case let .metrics(result) = ContentDetector.detect("Velocity\t42\nBugs\t12\nCoverage\t81%") else {
            Issue.record("table was classified as text")
            return
        }
        #expect(result.metrics.count == 3)
    }

    @Test("Empty and unparseable input return nil")
    func garbage() {
        #expect(MetricsParser.parse("") == nil)
        #expect(MetricsParser.parse("   \n  ") == nil)
        #expect(MetricsParser.parse("just a sentence with no numbers") == nil)
    }

    @Test("Sentiment heuristics treat cost-like labels as lower-is-better")
    func sentiment() {
        #expect(SentimentHeuristics.sentiment(for: .up, label: "Velocity") == .positive)
        #expect(SentimentHeuristics.sentiment(for: .up, label: "P1 incidents") == .negative)
        #expect(SentimentHeuristics.sentiment(for: .down, label: "Cloud cost") == .positive)
        #expect(SentimentHeuristics.sentiment(for: .flat, label: "Anything") == .neutral)
    }
}

@Suite("MetricsParser OCR helpers")
struct MetricsParserOCRTests {
    @Test("Bare 'Label 42' lines parse only when explicitly allowed")
    func bareNumbers() throws {
        let text = "Velocity 42\nOpen bugs 12\nCoverage 81%"
        #expect(MetricsParser.parse(text) == nil)
        let result = try #require(MetricsParser.parse(text, allowBareNumbers: true))
        #expect(result.metrics.map(\.label) == ["Velocity", "Open bugs", "Coverage"])
        #expect(result.metrics.map(\.value) == ["42", "12", "81%"])
    }

    @Test("Label and value on separate lines are paired")
    func pairing() {
        let lines = ["Velocity", "42", "Open bugs", "12", "Notes", "Coverage", "81%", "trailing"]
        #expect(MetricsParser.pairLabelValueLines(lines) == ["Velocity: 42", "Open bugs: 12", "Notes", "Coverage: 81%", "trailing"])
    }
}

@Suite("Duplication")
struct DuplicationTests {
    @Test("Duplicated cards share content but not identifiers")
    func duplicate() {
        let original = Fixtures.card()
        let copy = original.duplicated()
        #expect(copy.id != original.id)
        #expect(copy.title == "Weekly status <Atlas> copy")
        #expect(copy.blocks.count == original.blocks.count)
        #expect(Set(copy.blocks.map(\.id)).isDisjoint(with: original.blocks.map(\.id)))
        #expect(copy.blocks.map(\.kind) == original.blocks.map(\.kind))
    }
}
