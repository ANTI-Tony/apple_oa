import Foundation
import Testing
@testable import ReportCore

@Suite("CardDraftParser")
struct CardDraftTests {
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    private let reply = """
    Here is the report:
    ```json
    {
      "title": "Atlas weekly status",
      "subtitle": "Project Atlas, week 38",
      "status": "At Risk",
      "summary": "Pilot is live in three regions; the launch date needs a decision.",
      "highlights": ["Pilot live in 3 of 5 regions", "- Vendor rate limit resolved"],
      "metrics": [
        {"label": "Velocity", "value": "42", "change": "+5%"},
        {"label": "Open bugs", "value": "12", "change": "-3"},
        {"label": "", "value": "7"}
      ],
      "risks": ["Launch date undecided"],
      "next_steps": ["Load test on staging"]
    }
    ```
    """

    @Test("JSON is found inside prose and code fences; snake_case keys are accepted")
    func parsing() throws {
        let draft = try CardDraftParser.parse(reply)
        #expect(draft.title == "Atlas weekly status")
        #expect(draft.nextSteps == ["Load test on staging"])
        #expect(draft.metrics?.count == 3)
    }

    @Test("A draft becomes a card with sections, parsed changes and a mapped status")
    func makeCard() throws {
        let card = try CardDraftParser.makeCard(from: CardDraftParser.parse(reply), theme: .paper, author: "Alex", now: fixedDate)
        #expect(card.title == "Atlas weekly status")
        #expect(card.status == .atRisk)
        #expect(card.theme == .paper)
        #expect(card.author == "Alex")
        #expect(card.updatedAt == fixedDate)
        #expect(card.blocks.map(\.heading) == ["Summary", "Highlights", "Key metrics", "Risks and asks", "Next steps"])

        guard case let .text(highlights) = card.blocks[1] else { Issue.record("expected text")
            return
        }
        #expect(highlights.body == "• Pilot live in 3 of 5 regions\n• Vendor rate limit resolved", "stray bullet characters are stripped")

        guard case let .metrics(metrics) = card.blocks[2] else { Issue.record("expected metrics")
            return
        }
        #expect(metrics.metrics.count == 2, "a metric without a label is dropped")
        #expect(metrics.metrics[0].change == MetricChange(direction: .up, sentiment: .positive, text: "5%"))
        #expect(metrics.metrics[1].change?.sentiment == .positive, "fewer bugs is good news")
    }

    @Test("A generated card passes the accessibility linter's error rules")
    func generatedCardIsAccessible() throws {
        let card = try CardDraftParser.makeCard(from: CardDraftParser.parse(reply))
        #expect(AccessibilityLinter.lint(card).isCompliant)
    }

    @Test("Runaway output is bounded")
    func bounds() throws {
        let draft = CardDraft(
            title: String(repeating: "T", count: 500),
            highlights: (1 ... 40).map { "Item \($0) " + String(repeating: "x", count: 400) },
            metrics: (1 ... 30).map { CardDraft.DraftMetric(label: "M\($0)", value: "\($0)") }
        )
        let card = try CardDraftParser.makeCard(from: draft)
        #expect(card.title.count == CardDraftParser.maxTitleLength)
        guard case let .text(highlights) = card.blocks[0], case let .metrics(metrics) = card.blocks[1] else {
            Issue.record("unexpected blocks")
            return
        }
        let lines = highlights.body.components(separatedBy: "\n")
        #expect(lines.count == CardDraftParser.maxItemsPerList)
        #expect(lines.allSatisfy { $0.count <= CardDraftParser.maxItemLength + 2 })
        #expect(metrics.metrics.count == CardDraftParser.maxItemsPerList)
    }

    @Test("Status words are mapped loosely and default to on track")
    func statuses() {
        #expect(CardDraftParser.status(from: "on_track") == .onTrack)
        #expect(CardDraftParser.status(from: "RED") == .offTrack)
        #expect(CardDraftParser.status(from: "amber") == .atRisk)
        #expect(CardDraftParser.status(from: "Done") == .completed)
        #expect(CardDraftParser.status(from: "not started") == .notStarted)
        #expect(CardDraftParser.status(from: nil) == .onTrack)
        #expect(CardDraftParser.status(from: "purple") == .onTrack)
    }

    @Test("Unusable replies produce typed errors")
    func errors() {
        #expect(throws: CardDraftError.noJSONFound) { try CardDraftParser.parse("Sorry, I cannot help with that.") }
        #expect(throws: CardDraftError.self) { try CardDraftParser.parse("{ not json }") }
        #expect(throws: CardDraftError.empty) { try CardDraftParser.makeCard(from: CardDraft(title: "Only a title")) }
    }

    @Test("Prompts state the rules that protect the user")
    func prompts() {
        #expect(AssistantPrompts.draftSystem.contains("Never invent or estimate a number"))
        #expect(AssistantPrompts.draftSystem.contains("single JSON object"))
        #expect(AssistantPrompts.draftUser(notes: "  hello \n").contains("\"\"\"\nhello\n\"\"\""))
        for style in RefineStyle.allCases {
            let system = AssistantPrompts.refineSystem(style)
            #expect(system.contains("Keep every number, name and date exactly as written"))
            #expect(system.contains("• "))
        }
    }

    @Test("Refinement replies are unwrapped from fences and quotes")
    func cleanedRefinement() {
        #expect(AssistantPrompts.cleanedRefinement("```\n• One\n• Two\n```") == "• One\n• Two")
        #expect(AssistantPrompts.cleanedRefinement("\"Shorter text.\"") == "Shorter text.")
        #expect(AssistantPrompts.cleanedRefinement("  Plain.  ") == "Plain.")
    }
}
