import Foundation
import ReportCore

/// Cards seeded on first launch so the app never opens empty.
@MainActor
enum SampleContent {
    static func cards() -> [SnippetCard] {
        [weeklyStatus(), risks(), incident()]
    }

    static func weeklyStatus() -> SnippetCard {
        var blocks: [Block] = [
            .text(TextBlock(heading: "Highlights", body: """
            - Pilot rollout reached 3 of 5 regional teams
            - Vendor API rate limit resolved; integration tests are green again
            - Accessibility audit: 14 of 16 findings closed
            """)),
            .metrics(MetricsBlock(heading: "Key metrics", metrics: [
                Metric(
                    label: "Velocity",
                    value: "42",
                    change: MetricChange(direction: .up, sentiment: .positive, text: "5%"),
                    trend: [36, 38, 37, 40, 42]
                ),
                Metric(
                    label: "Open bugs",
                    value: "12",
                    change: MetricChange(direction: .down, sentiment: .positive, text: "20%"),
                    trend: [21, 18, 17, 15, 12]
                ),
                Metric(
                    label: "Test coverage",
                    value: "81%",
                    change: MetricChange(direction: .up, sentiment: .positive, text: "2 pts"),
                    trend: [74, 76, 78, 79, 81]
                ),
            ])),
            .text(TextBlock(heading: "Next week", body: """
            - Run the load test on staging
            - Close the remaining two audit findings
            """)),
            .text(TextBlock(heading: "Risks and asks", body: "Launch date decision needed from the steering group by Wednesday.")),
        ]
        if let image = sampleImageBlock() {
            blocks.insert(image, at: 2)
        }
        return SnippetCard(title: "Weekly status", subtitle: "Project Atlas · Week 38", status: .onTrack, blocks: blocks)
    }

    static func risks() -> SnippetCard {
        var card = CardTemplate.risks.makeCard()
        card.subtitle = "Project Atlas"
        card.theme = .ocean
        return card
    }

    static func incident() -> SnippetCard {
        var card = CardTemplate.incident.makeCard()
        card.subtitle = "Checkout service · INC-2047"
        card.theme = .dark
        return card
    }

    static func sampleImageBlock() -> Block? {
        guard let url = Bundle.main.url(forResource: "sample-burndown", withExtension: "png"),
              let data = try? Data(contentsOf: url),
              let type = ImageContentType.detect(from: data) else { return nil }
        return .image(ImageBlock(
            imageData: data,
            contentType: type,
            altText: "Sprint 14 burndown line chart. Remaining story points fell from 48 to 9 over ten days, "
                + "behind the ideal line until day 5 and ahead of it afterwards.",
            caption: "Sprint 14 burndown, 2 days left",
            pixelSize: ImageImport.pixelSize(of: data),
            fileName: "sample-burndown.png"
        ))
    }
}
