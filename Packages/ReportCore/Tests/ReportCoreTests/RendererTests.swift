import Foundation
import Testing
@testable import ReportCore

@Suite("HTMLRenderer")
struct HTMLRendererTests {
    let card = Fixtures.card()

    @Test("Email fragment is a single article with inline styles and no stylesheet")
    func emailFragment() {
        let html = HTMLRenderer(options: .email).render(card)
        #expect(html.hasPrefix("<article lang=\"en\""))
        #expect(html.hasSuffix("</article>"))
        #expect(!html.contains("<style"))
        #expect(!html.contains("<!doctype"))
        #expect(html.contains("style=\"max-width:600px"))
    }

    @Test("Standalone document has doctype, lang, viewport and title")
    func standalone() {
        let html = HTMLRenderer(options: .standalone).render(card)
        #expect(html.hasPrefix("<!doctype html>"))
        #expect(html.contains("<html lang=\"en\">"))
        #expect(html.contains("name=\"viewport\""))
        #expect(html.contains("<title>Weekly status &lt;Atlas&gt;</title>"))
    }

    @Test("User content is escaped, so a title cannot inject markup")
    func escaping() {
        var hostile = card
        hostile.title = "<script>alert(1)</script>"
        let html = HTMLRenderer().render(hostile)
        #expect(!html.contains("<script>"))
        #expect(html.contains("&lt;script&gt;"))
        #expect(html.contains("Shipped v1.2 &amp; docs"))
    }

    @Test("Images carry alt text, dimensions and an embedded data URI")
    func images() {
        let html = HTMLRenderer().render(card)
        #expect(html.contains("alt=\"Burndown chart trending to zero by Friday\""))
        #expect(html.contains("width=\"1\" height=\"1\""))
        #expect(html.contains("src=\"data:image/png;base64,"))
        #expect(html.contains("<figcaption"))
    }

    @Test("Decorative images get empty alt and presentation role")
    func decorativeImage() {
        var decorated = card
        decorated.blocks = [.image(Fixtures.image(alt: "", decorative: true))]
        let html = HTMLRenderer().render(decorated)
        #expect(html.contains("alt=\"\" role=\"presentation\""))
    }

    @Test("Images can be referenced by file name for folder exports")
    func imageFileReferences() {
        let html = HTMLRenderer(options: .init(embedImages: false)).render(card)
        #expect(html.contains("src=\"image-1.png\""))
        #expect(!html.contains("base64"))
    }

    @Test("Change indicators hide the glyph from screen readers and add spoken text")
    func changeAccessibility() {
        let html = HTMLRenderer().render(card)
        #expect(html.contains("<span aria-hidden=\"true\">▲ 5%</span>"))
        #expect(html.contains("up 5%, positive</span>"))
        #expect(html.contains(HTMLRenderer.visuallyHiddenStyle))
    }

    @Test("Table layout uses header scopes")
    func tableLayout() {
        var tabular = card
        let metric = Metric(label: "Velocity", value: "42", change: MetricChange(direction: .up, text: "5%"))
        tabular.blocks = [.metrics(MetricsBlock(heading: "Numbers", metrics: [metric], layout: .table))]
        let html = HTMLRenderer().render(tabular)
        #expect(html.contains("<th scope=\"col\""))
        #expect(html.contains("<th scope=\"row\""))
        #expect(html.contains("Change</th>"))
    }

    @Test("Status is conveyed with text, not colour alone")
    func statusText() {
        let html = HTMLRenderer().render(Fixtures.card(status: .offTrack))
        #expect(html.contains("Status: Off track"))
    }

    @Test("Empty blocks render nothing")
    func emptyBlocks() {
        var sparse = card
        sparse.blocks = [.text(TextBlock()), .metrics(MetricsBlock(heading: "Empty"))]
        let html = HTMLRenderer().render(sparse)
        #expect(!html.contains("<section"))
    }
}

@Suite("MarkdownRenderer")
struct MarkdownRendererTests {
    let card = Fixtures.card()

    @Test("CommonMark output has headings, bullets and a GFM table")
    func commonMark() {
        let markdown = MarkdownRenderer(flavor: .commonMark, includeFooter: false).render(card)
        #expect(markdown.hasPrefix("# Weekly status <Atlas>"))
        #expect(markdown.contains("## Highlights"))
        #expect(markdown.contains("- Shipped v1.2 & docs"))
        #expect(markdown.contains("| Metric | Value | Change |"))
        #expect(markdown.contains("| Velocity | 42 | ▲ 5% |"))
        #expect(markdown.contains("![Burndown chart trending to zero by Friday](image-1.png)"))
        #expect(markdown.contains("Status: ● On track"))
    }

    @Test("Slack flavour uses bold lines instead of headings and tables")
    func slack() {
        let markdown = MarkdownRenderer(flavor: .slack, includeFooter: false).render(card)
        #expect(markdown.hasPrefix("*Weekly status <Atlas>*"))
        #expect(!markdown.contains("#"))
        #expect(!markdown.contains("|---"))
        #expect(markdown.contains("• *Velocity*: 42 (▲ 5%)"))
        #expect(markdown.contains("_[Image: Burndown chart trending to zero by Friday]_"))
    }

    @Test("Markdown control characters in content are escaped")
    func escaping() {
        var tricky = card
        tricky.title = "Q3 *plan* [draft]"
        let markdown = MarkdownRenderer(includeFooter: false).render(tricky)
        #expect(markdown.hasPrefix("# Q3 \\*plan\\* \\[draft\\]"))
    }
}

@Suite("PlainTextRenderer")
struct PlainTextRendererTests {
    @Test("Plain text reads sensibly top to bottom")
    func plain() {
        let text = PlainTextRenderer(includeFooter: false).render(Fixtures.card())
        let lines = text.components(separatedBy: "\n")
        #expect(lines[0] == "WEEKLY STATUS <ATLAS>")
        #expect(lines[1] == "Project Atlas · Week 38")
        #expect(lines[2] == "Status: On track")
        #expect(text.contains("Velocity: 42 (up 5%, positive)"))
        #expect(text.contains("[Image: Burndown chart trending to zero by Friday]"))
    }
}

@Suite("Footer and heading options")
struct FooterAndHeadingTests {
    private let locale = Locale(identifier: "en_US")

    @Test("Footer names the author only when there is one")
    func footerText() {
        var card = Fixtures.card()
        // The date is formatted in the machine's time zone, so derive it rather than hard-coding it.
        let date = CardDateFormatting.footerDate(card.updatedAt, locale: locale)
        #expect(date.contains("2023"))
        #expect(CardDateFormatting.footerText(for: card, locale: locale) == "Updated \(date)")
        card.author = "  Alex Chen "
        #expect(CardDateFormatting.footerText(for: card, locale: locale) == "Updated \(date) · Alex Chen")
    }

    @Test("Every text renderer prints the same footer")
    func footerEverywhere() {
        var card = Fixtures.card()
        card.author = "Alex <Chen>"
        let date = CardDateFormatting.footerDate(card.updatedAt, locale: locale)
        let html = HTMLRenderer(options: .init(locale: locale)).render(card)
        #expect(html.contains("Updated \(date) · Alex &lt;Chen&gt;</p></footer>"))
        #expect(MarkdownRenderer(locale: locale).render(card).contains("_Updated \(date) · Alex <Chen>_"))
        #expect(PlainTextRenderer(locale: locale).render(card).hasSuffix("Updated \(date) · Alex <Chen>\n"))
    }

    @Test("Author survives a JSON round trip and defaults to empty for old files")
    func authorCoding() throws {
        var card = Fixtures.card()
        card.author = "Alex Chen"
        #expect(try CardCodec.decodeCard(CardCodec.encode(card)).author == "Alex Chen")
        #expect(try CardCodec.decodeCard(Data(#"{"title": "Old"}"#.utf8)).author.isEmpty)
    }

    @Test("Base heading level shifts the title and block headings together")
    func headingLevels() {
        let card = Fixtures.card()
        let standard = HTMLRenderer().render(card)
        #expect(standard.contains("<h1 style="))
        #expect(standard.contains("<h2 id="))

        let embedded = HTMLRenderer(options: .init(baseHeadingLevel: 3)).render(card)
        #expect(!embedded.contains("<h1"))
        #expect(!embedded.contains("<h2"))
        #expect(embedded.contains("<h3 style="))
        #expect(embedded.contains("</h3>"))
        #expect(embedded.contains("<h4 id="))

        #expect(HTMLRenderer.Options(baseHeadingLevel: 9).baseHeadingLevel == 5)
        #expect(HTMLRenderer.Options(baseHeadingLevel: 0).baseHeadingLevel == 1)
    }
}
