import Foundation
import Testing
@testable import ReportCore

@Suite("Content accessibility checks")
struct ContentChecksTests {
    private func rules(_ card: SnippetCard) -> [AccessibilityRule] {
        AccessibilityLinter.lint(card).issues.map(\.rule)
    }

    @Test("Pointing at something by colour alone is flagged, plain colour words are not")
    func colourLanguage() {
        let flagged = SnippetCard(
            title: "T",
            blocks: [.text(TextBlock(heading: "Risks", body: "The items marked in red need a decision."))]
        )
        #expect(rules(flagged).contains(.meaningNotByColorAlone))
        let alsoFlagged = SnippetCard(title: "T", blocks: [.text(TextBlock(heading: "Risks", body: "Please review the green rows first."))])
        #expect(rules(alsoFlagged).contains(.meaningNotByColorAlone))
        let fine = SnippetCard(
            title: "T",
            blocks: [.text(TextBlock(heading: "Status", body: "Project Red Sea moved to the blue team. Reduced risk overall."))]
        )
        #expect(!rules(fine).contains(.meaningNotByColorAlone))
    }

    @Test("Four capitalised words in a row are flagged, acronyms are not")
    func capitals() {
        let shouting = SnippetCard(title: "T", blocks: [.text(TextBlock(heading: "Note", body: "THIS MUST SHIP BY FRIDAY or we slip."))])
        #expect(rules(shouting).contains(.noLongRunsOfCapitals))
        let acronyms = SnippetCard(
            title: "T",
            blocks: [.text(TextBlock(heading: "Note", body: "The API and SDK passed QA. CI is green on iOS."))]
        )
        #expect(!rules(acronyms).contains(.noLongRunsOfCapitals))
    }

    @Test("Very long sentences are flagged")
    func readability() {
        let long = Array(repeating: "word", count: 40).joined(separator: " ") + "."
        let card = SnippetCard(title: "T", blocks: [.text(TextBlock(heading: "Summary", body: long))])
        #expect(rules(card).contains(.sentencesAreReadable))
        #expect(ContentChecks.averageSentenceLength("One two three. Four five.") == 2.5)
        #expect(ContentChecks.averageSentenceLength("") == 0)
    }

    @Test("Bullets count as separate sentences, so lists are never 'long sentences'")
    func bulletsAreSentences() {
        let body = (1 ... 8).map { "• Item number \($0) was delivered on time" }.joined(separator: "\n")
        let card = SnippetCard(title: "T", blocks: [.text(TextBlock(heading: "Done", body: body))])
        #expect(!rules(card).contains(.sentencesAreReadable))
    }

    @Test("Three or more sections need headings; the issue points at the first one missing")
    func headings() {
        let untitled = TextBlock(body: "No heading here.")
        let card = SnippetCard(title: "T", blocks: [
            .text(TextBlock(heading: "A", body: "a")), .text(untitled), .metrics(MetricsBlock(
                heading: "",
                metrics: [Metric(label: "L", value: "1")]
            )),
        ])
        let issue = AccessibilityLinter.lint(card).issues.first { $0.rule == .sectionsHaveHeadings }
        #expect(issue?.blockID == untitled.id)
        #expect(issue?.message.hasPrefix("2 sections have") == true)

        let short = SnippetCard(title: "T", blocks: [.text(untitled), .text(TextBlock(body: "Also none."))])
        #expect(!rules(short).contains(.sectionsHaveHeadings), "two short sections do not need headings")
    }

    @Test("An image that is mostly text is flagged unless its description carries the content")
    func imagesOfText() {
        var image = Fixtures.image(alt: "Dashboard")
        image.recognizedWordCount = 60
        #expect(rules(SnippetCard(title: "T", blocks: [.image(image)])).contains(.noImagesOfText))

        image.altText = Array(repeating: "fact", count: 35).joined(separator: " ")
        #expect(!rules(SnippetCard(title: "T", blocks: [.image(image)])).contains(.noImagesOfText))

        image.altText = "Dashboard"
        image.recognizedWordCount = 4
        #expect(!rules(SnippetCard(title: "T", blocks: [.image(image)])).contains(.noImagesOfText))

        image.recognizedWordCount = nil
        #expect(!rules(SnippetCard(title: "T", blocks: [.image(image)])).contains(.noImagesOfText), "unknown is not a finding")
    }

    @Test("Content findings are warnings: they never block a card from being compliant")
    func severity() {
        let card = SnippetCard(title: "T", blocks: [.text(TextBlock(heading: "X", body: "SHOUT SHOUT SHOUT SHOUT see the red items"))])
        let report = AccessibilityLinter.lint(card)
        #expect(report.isCompliant)
        #expect(report.warnings.count == 2)
    }

    @Test("There are fourteen rules and every one has a title and a reference")
    func ruleCatalogue() {
        #expect(AccessibilityRule.allCases.count == 14)
        for rule in AccessibilityRule.allCases {
            #expect(!rule.title.isEmpty)
            #expect(!rule.wcagReference.isEmpty)
        }
    }
}

@Suite("Large print")
struct LargePrintTests {
    @Test("HTML type scales with the card's text size; layout metrics do not")
    func htmlScale() {
        var card = Fixtures.card()
        let standard = HTMLRenderer().render(card)
        #expect(standard.contains("font-size:28px"))
        #expect(standard.contains("font-size:15px"))

        card.textSize = .extraLarge
        let large = HTMLRenderer().render(card)
        #expect(large.contains("font-size:39px"), "28 × 1.4")
        #expect(large.contains("font-size:21px"), "15 × 1.4")
        #expect(!large.contains("font-size:28px"))
        #expect(large.contains("padding:28px"), "padding is not type")
    }

    @Test("Text size survives JSON and defaults to standard for older files")
    func coding() throws {
        var card = Fixtures.card()
        card.textSize = .large
        #expect(try CardCodec.decodeCard(CardCodec.encode(card)).textSize == .large)
        #expect(try CardCodec.decodeCard(Data(#"{"title": "Old"}"#.utf8)).textSize == .standard)
    }
}

@Suite("Structural equality")
struct StructuralEqualityTests {
    @Test("Rewording is not structural; adding, moving, restyling is")
    func structure() {
        let card = Fixtures.card()
        var reworded = card
        reworded.title = "Different"
        reworded.subtitle = "Also different"
        if case var .text(text) = reworded.blocks[0] {
            text.body = "rewritten"
            reworded.blocks[0] = .text(text)
        }
        if case var .metrics(metrics) = reworded.blocks[1] {
            metrics.metrics[0].value = "99"
            reworded.blocks[1] = .metrics(metrics)
        }
        #expect(card.isStructurallyEqual(to: reworded))

        var moved = card
        moved.moveBlock(withID: card.blocks[0].id, by: 1)
        #expect(!card.isStructurallyEqual(to: moved))

        var themed = card
        themed.theme = .dark
        #expect(!card.isStructurallyEqual(to: themed))

        var resized = card
        resized.textSize = .large
        #expect(!card.isStructurallyEqual(to: resized))

        var grown = card
        grown.append(.text(TextBlock(body: "new")))
        #expect(!card.isStructurallyEqual(to: grown))

        var flipped = card
        if case var .metrics(metrics) = flipped.blocks[1] {
            metrics.metrics[0].change?.sentiment = .negative
            flipped.blocks[1] = .metrics(metrics)
        }
        #expect(!card.isStructurallyEqual(to: flipped), "overriding good/bad news is a deliberate act worth undoing")
    }
}

@Suite("Undo action names")
struct ChangeNameTests {
    @Test("Structural changes are named; rewording is not")
    func names() {
        let card = Fixtures.card()
        var edited = card
        edited.title = "Reworded"
        #expect(edited.structuralChangeName(since: card) == nil)

        edited = card
        edited.append(.text(TextBlock(body: "x")))
        #expect(edited.structuralChangeName(since: card) == "Add Block")

        edited = card
        edited.removeBlock(withID: card.blocks[0].id)
        #expect(edited.structuralChangeName(since: card) == "Delete Block")

        edited = card
        edited.moveBlock(withID: card.blocks[0].id, by: 1)
        #expect(edited.structuralChangeName(since: card) == "Move Block")

        edited = card
        edited.theme = .paper
        #expect(edited.structuralChangeName(since: card) == "Change Theme")

        edited = card
        edited.status = .atRisk
        #expect(edited.structuralChangeName(since: card) == "Change Status")

        edited = card
        edited.textSize = .large
        #expect(edited.structuralChangeName(since: card) == "Change Text Size")

        edited = card
        if case var .metrics(metrics) = edited.blocks[1] {
            metrics.layout = .table
            edited.blocks[1] = .metrics(metrics)
        }
        #expect(edited.structuralChangeName(since: card) == "Change Layout")

        edited = card
        if case var .metrics(metrics) = edited.blocks[1] {
            metrics.metrics.append(Metric(label: "New", value: "1"))
            edited.blocks[1] = .metrics(metrics)
        }
        #expect(edited.structuralChangeName(since: card) == "Add Metric")
    }
}
