import Foundation

/// A starting point for a new card.
public struct CardTemplate: Identifiable, Sendable {
    public var id: String
    public var name: String
    public var summary: String
    public var symbolName: String
    private let factory: @Sendable (_ now: Date, _ locale: Locale) -> SnippetCard

    public init(
        id: String,
        name: String,
        summary: String,
        symbolName: String,
        factory: @escaping @Sendable (_ now: Date, _ locale: Locale) -> SnippetCard
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.symbolName = symbolName
        self.factory = factory
    }

    /// Creates a fresh card with new identifiers each time.
    ///
    /// - Parameters:
    ///   - now: stamped as the creation date and used for any date in the
    ///     content. Injected so CI output is reproducible.
    ///   - locale: used to format dates inside the content.
    public func makeCard(now: Date = Date(), locale: Locale = .current) -> SnippetCard {
        var card = factory(now, locale)
        card.createdAt = now
        card.updatedAt = now
        return card
    }
}

public extension CardTemplate {
    static let blank = CardTemplate(
        id: "blank", name: "Blank", summary: "An empty card.", symbolName: "rectangle"
    ) { _, _ in
        SnippetCard(title: "Untitled report")
    }

    static let weeklyStatus = CardTemplate(
        id: "weekly_status", name: "Weekly status",
        summary: "Highlights, key metrics and next steps for the week.",
        symbolName: "calendar"
    ) { now, locale in
        SnippetCard(
            title: "Weekly status",
            subtitle: "Project name · Week of \(CardDateFormatting.footerDate(now, locale: locale))",
            status: .onTrack,
            blocks: [
                .text(TextBlock(heading: "Highlights", body: """
                - Shipped the first milestone to the pilot group
                - Closed the top three customer-reported issues
                """)),
                .metrics(MetricsBlock(heading: "Key metrics", metrics: [
                    Metric(
                        label: "Velocity",
                        value: "42",
                        change: MetricChange(direction: .up, sentiment: .positive, text: "5%")
                    ),
                    Metric(
                        label: "Open bugs",
                        value: "12",
                        change: MetricChange(direction: .down, sentiment: .positive, text: "3")
                    ),
                    Metric(
                        label: "Test coverage",
                        value: "81%",
                        change: MetricChange(direction: .up, sentiment: .positive, text: "2 pts")
                    ),
                ])),
                .text(TextBlock(heading: "Next week", body: """
                - Start the load test on the staging environment
                - Review the accessibility audit findings
                """)),
                .text(TextBlock(heading: "Risks and asks", body: "None this week.")),
            ]
        )
    }

    static let milestone = CardTemplate(
        id: "milestone", name: "Milestone update",
        summary: "Progress against one milestone with a date and a blocker list.",
        symbolName: "flag"
    ) { _, _ in
        SnippetCard(
            title: "Milestone update",
            subtitle: "Project name · Milestone 2",
            status: .onTrack,
            blocks: [
                .text(TextBlock(
                    heading: "Summary",
                    body: "One paragraph on where the milestone stands and what changed since the last update."
                )),
                .metrics(MetricsBlock(heading: "Progress", metrics: [
                    Metric(
                        label: "Scope complete",
                        value: "68%",
                        change: MetricChange(direction: .up, sentiment: .positive, text: "9 pts")
                    ),
                    Metric(label: "Target date", value: "30 Sep"),
                    Metric(label: "Days remaining", value: "12"),
                ])),
                .text(TextBlock(heading: "Blockers", body: "- None")),
            ]
        )
    }

    static let risks = CardTemplate(
        id: "risks", name: "Risks and issues",
        summary: "A table of open risks with owners and mitigation.",
        symbolName: "exclamationmark.triangle"
    ) { _, _ in
        SnippetCard(
            title: "Risks and issues",
            subtitle: "Project name",
            status: .atRisk,
            blocks: [
                .metrics(MetricsBlock(heading: "Open items", metrics: [
                    Metric(label: "High risks", value: "1", change: MetricChange(direction: .flat, sentiment: .neutral, text: "")),
                    Metric(
                        label: "Medium risks",
                        value: "3",
                        change: MetricChange(direction: .up, sentiment: .negative, text: "1")
                    ),
                    Metric(
                        label: "Issues overdue",
                        value: "0",
                        change: MetricChange(direction: .down, sentiment: .positive, text: "2")
                    ),
                ], layout: .table)),
                .text(TextBlock(heading: "Top risk", body: """
                Vendor API rate limits may delay the integration test.
                - Owner: Integration lead
                - Mitigation: request a higher quota; fall back to a mocked endpoint for the test window
                """)),
                .text(TextBlock(heading: "Decisions needed", body: "- Approve the two-day schedule buffer")),
            ]
        )
    }

    static let incident = CardTemplate(
        id: "incident", name: "Incident summary",
        summary: "Impact, timeline and follow-ups after an incident.",
        symbolName: "bolt.horizontal"
    ) { _, _ in
        SnippetCard(
            title: "Incident summary",
            subtitle: "Service name · INC-0000",
            status: .completed,
            blocks: [
                .text(TextBlock(heading: "Impact", body: "Describe who was affected, for how long and how it was detected.")),
                .metrics(MetricsBlock(heading: "Numbers", metrics: [
                    Metric(label: "Duration", value: "47 min"),
                    Metric(label: "Users affected", value: "1.2k"),
                    Metric(label: "Error rate peak", value: "8.4%"),
                ])),
                .text(TextBlock(heading: "Timeline", body: """
                - 09:12 Alert fired
                - 09:20 Root cause identified
                - 09:59 Fix deployed, error rate back to baseline
                """)),
                .text(TextBlock(heading: "Follow-ups", body: "- Add a canary check for the failing dependency")),
            ]
        )
    }

    static let sprintReview = CardTemplate(
        id: "sprint_review", name: "Sprint review",
        summary: "What shipped, what slipped, and the numbers behind it.",
        symbolName: "arrow.triangle.2.circlepath"
    ) { _, _ in
        SnippetCard(
            title: "Sprint review",
            subtitle: "Team name · Sprint 14",
            status: .onTrack,
            blocks: [
                .text(TextBlock(heading: "Shipped", body: "- Feature A\n- Feature B")),
                .text(TextBlock(heading: "Slipped", body: "- Feature C, moved to next sprint")),
                .metrics(MetricsBlock(heading: "Sprint metrics", metrics: [
                    Metric(label: "Points planned", value: "48"),
                    Metric(
                        label: "Points done",
                        value: "44",
                        change: MetricChange(direction: .up, sentiment: .positive, text: "6%")
                    ),
                    Metric(
                        label: "Carry-over",
                        value: "4",
                        change: MetricChange(direction: .down, sentiment: .positive, text: "2")
                    ),
                    Metric(
                        label: "Bugs found",
                        value: "7",
                        change: MetricChange(direction: .up, sentiment: .negative, text: "2")
                    ),
                ])),
            ]
        )
    }

    static let builtIn: [CardTemplate] = [.weeklyStatus, .milestone, .risks, .incident, .sprintReview, .blank]

    static func builtIn(id: String) -> CardTemplate? {
        builtIn.first { $0.id == id }
    }
}
