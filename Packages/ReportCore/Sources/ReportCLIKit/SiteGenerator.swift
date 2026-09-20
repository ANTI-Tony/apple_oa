import Foundation
import ReportCore

/// Builds the static gallery published to GitHub Pages: one accessible,
/// responsive index page plus every template as standalone HTML (in each
/// theme), Markdown and JSON.
///
/// The cards on the page are produced by the very `HTMLRenderer` the macOS app
/// uses for email, so the site doubles as a living regression sample of that
/// output in real browsers.
public struct SiteGenerator {
    public var generatedAt: Date
    public var repositoryURL: String?
    public var locale: Locale

    public init(generatedAt: Date = Date(), repositoryURL: String? = nil, locale: Locale = Locale(identifier: "en_US")) {
        self.generatedAt = generatedAt
        self.repositoryURL = repositoryURL
        self.locale = locale
    }

    /// Writes the site and returns the relative paths written, sorted.
    @discardableResult
    public func generate(into directory: URL) throws -> [String] {
        let fileManager = FileManager.default
        let cardsDirectory = directory.appendingPathComponent("cards", isDirectory: true)
        try fileManager.createDirectory(at: cardsDirectory, withIntermediateDirectories: true)

        var written: [String] = []
        func write(_ text: String, to relativePath: String) throws {
            try Data(text.utf8).write(to: directory.appendingPathComponent(relativePath), options: .atomic)
            written.append(relativePath)
        }

        var sections: [String] = []
        for template in CardTemplate.builtIn where template.id != CardTemplate.blank.id {
            let card = template.makeCard(now: generatedAt, locale: locale)

            // The gallery is a showcase of accessible output; refuse to publish a
            // template that regressed.
            let report = AccessibilityLinter.lint(card)
            guard report.isCompliant else {
                throw CLIError.invalidInput("Template \(template.id) fails accessibility checks: \(report.summary)")
            }

            var themeLinks: [String] = []
            for theme in CardTheme.builtIn {
                var themed = card
                themed.theme = theme
                let page = HTMLRenderer(options: .init(mode: .standaloneDocument, locale: locale)).render(themed)
                let path = "cards/\(template.id)-\(theme.id).html"
                try write(page, to: path)
                themeLinks.append("<a href=\"\(path)\">\(theme.name.htmlEscaped)</a>")
            }
            try write(MarkdownRenderer(locale: locale).render(card), to: "cards/\(template.id).md")
            if let json = try String(data: CardCodec.encode(card), encoding: .utf8) {
                try write(json, to: "cards/\(template.id).json")
            }

            // Embedded cards start at <h3> so the page outline stays h1 > h2 > h3 > h4.
            let fragment = HTMLRenderer(options: .init(mode: .emailFragment, locale: locale, baseHeadingLevel: 3)).render(card)
            sections.append("""
            <section class="entry" aria-labelledby="t-\(template.id)">
            <h2 id="t-\(template.id)">\(template.name.htmlEscaped)</h2>
            <p class="summary">\(template.summary.htmlEscaped)</p>
            \(fragment)
            <p class="links"><span>Standalone page:</span> \(themeLinks.joined(separator: " "))
            <span class="sep">Data:</span> <a href="cards/\(template.id).md">Markdown</a> <a href="cards/\(template.id).json">JSON</a></p>
            </section>
            """)
        }

        try write(indexPage(sections: sections), to: "index.html")
        return written.sorted()
    }

    private func indexPage(sections: [String]) -> String {
        let date = CardDateFormatting.footerDate(generatedAt, locale: locale)
        let source = repositoryURL.map { " <a href=\"\($0.htmlEscaped)\">Source on GitHub</a>." } ?? ""
        return """
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Reporting Builder · Card gallery</title>
        <meta name="description" content="Snippet Cards rendered by the Reporting Builder HTML renderer.">
        <style>
        :root { color-scheme: light dark; --bg: #f5f5f7; --fg: #1d1d1f; --muted: #6e6e73; --link: #0066cc; --focus: #0066cc; }
        @media (prefers-color-scheme: dark) {
          :root { --bg: #111113; --fg: #f5f5f7; --muted: #a1a1a6; --link: #2997ff; --focus: #2997ff; }
        }
        * { box-sizing: border-box; }
        body { margin: 0; background: var(--bg); color: var(--fg); line-height: 1.5;
               font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', Helvetica, Arial, sans-serif; }
        a { color: var(--link); }
        a:focus-visible { outline: 3px solid var(--focus); outline-offset: 2px; border-radius: 3px; }
        .skip { position: absolute; left: -9999px; top: 8px; background: var(--bg); padding: 8px 12px; border-radius: 6px; }
        .skip:focus { left: 8px; }
        header, main, footer { max-width: 1320px; margin: 0 auto; padding: 24px 16px; }
        header p, .summary, footer { color: var(--muted); }
        h1 { font-size: 28px; margin: 0 0 8px; }
        h2 { font-size: 19px; margin: 0 0 4px; }
        .grid { display: grid; gap: 40px 28px; grid-template-columns: repeat(auto-fill, minmax(min(100%, 420px), 1fr)); }
        .entry { min-width: 0; }
        .summary { margin: 0 0 14px; }
        .links { font-size: 14px; margin: 12px 0 0; }
        .links a { margin-right: 10px; }
        .links span { color: var(--muted); margin-right: 6px; }
        .links .sep { margin-left: 8px; }
        img { max-width: 100%; height: auto; }
        @media (prefers-reduced-motion: reduce) { * { transition: none !important; scroll-behavior: auto !important; } }
        </style>
        </head>
        <body>
        <a class="skip" href="#main">Skip to the cards</a>
        <header>
        <h1>Reporting Builder · Card gallery</h1>
        <p>Every card below is produced by the same HTML renderer the macOS app uses for “Copy for Email”:
        inline styles only, semantic markup, WCAG AA contrast. All of them pass the built-in accessibility linter.</p>
        </header>
        <main id="main">
        <div class="grid">
        \(sections.joined(separator: "\n"))
        </div>
        </main>
        <footer>
        <p>Generated \(date.htmlEscaped) by <code>reportcard site</code> in CI.\(source)</p>
        </footer>
        </body>
        </html>
        """
    }
}
