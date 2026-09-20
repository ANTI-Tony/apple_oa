import Foundation
@testable import ReportCore

enum Fixtures {
    /// A valid 1x1 transparent PNG.
    static let onePixelPNG = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==")!

    static func image(alt: String = "Burndown chart trending to zero by Friday", decorative: Bool = false) -> ImageBlock {
        ImageBlock(
            imageData: onePixelPNG,
            contentType: .png,
            altText: alt,
            caption: "Sprint burndown",
            isDecorative: decorative,
            pixelSize: PixelSize(width: 1, height: 1)
        )
    }

    static func card(status: ReportStatus = .onTrack, theme: CardTheme = .light) -> SnippetCard {
        SnippetCard(
            title: "Weekly status <Atlas>",
            subtitle: "Project Atlas · Week 38",
            status: status,
            blocks: [
                .text(TextBlock(heading: "Highlights", body: "- Shipped v1.2 & docs\n- Closed 3 bugs\n\nOverall a calm week.")),
                .metrics(MetricsBlock(heading: "Key metrics", metrics: [
                    Metric(label: "Velocity", value: "42", change: MetricChange(direction: .up, sentiment: .positive, text: "5%")),
                    Metric(label: "Open bugs", value: "12", change: MetricChange(direction: .down, sentiment: .positive, text: "3")),
                ])),
                .image(image()),
            ],
            theme: theme,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
