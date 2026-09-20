import Foundation
import Testing
@testable import ReportCore

@Suite("SpokenRenderer")
struct SpokenRendererTests {
    private let renderer = SpokenRenderer(includeFooter: false)

    @Test("Narration follows reading order and names what each thing is")
    func order() {
        let script = renderer.script(for: Fixtures.card()).components(separatedBy: "\n")
        #expect(script == [
            "Project Atlas · Week 38",
            "Heading level 1. Weekly status <Atlas>",
            "Status: On Track",
            "Heading level 2. Highlights",
            "List, 2 items.",
            "Shipped v1.2 & docs",
            "Closed 3 bugs",
            "Overall a calm week.",
            "Heading level 2. Key metrics",
            "Velocity: 42, up 5%, positive",
            "Open bugs: 12, down 3, positive",
            "Image. Burndown chart trending to zero by Friday",
            "Sprint burndown",
        ])
    }

    @Test("An undescribed image is announced as a gap; a decorative one is skipped")
    func images() {
        var card = Fixtures.card()
        card.blocks = [.image(Fixtures.image(alt: ""))]
        let segments = renderer.segments(for: card)
        let gap = segments.first { $0.kind == .gap }
        #expect(gap?.text == "Image. No description.")
        #expect(gap?.blockID == card.blocks[0].id)

        card.blocks = [.image(Fixtures.image(alt: "", decorative: true))]
        #expect(!renderer.script(for: card).contains("Image"))
    }

    @Test("Segments carry the block they come from, so the app can highlight while speaking")
    func blockIDs() {
        let card = Fixtures.card()
        let segments = renderer.segments(for: card)
        #expect(segments.first?.blockID == nil, "the header belongs to no block")
        #expect(segments.first { $0.text.hasPrefix("Velocity") }?.blockID == card.blocks[1].id)
        #expect(segments.map(\.id) == Array(segments.indices))
    }

    @Test("Unlabelled metrics are called out rather than read as a bare number")
    func unlabelled() {
        let card = SnippetCard(title: "T", blocks: [.metrics(MetricsBlock(heading: "", metrics: [Metric(label: "", value: "42")]))])
        #expect(renderer.script(for: card).contains("Unlabelled number: 42"))
    }
}
