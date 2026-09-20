import Foundation

/// Renders a card as HTML.
///
/// Two modes share one body:
/// - `.emailFragment` emits an `<article>` with every style inlined, because
///   Gmail, Outlook and Apple Mail strip `<style>` blocks from pasted or
///   forwarded content. Layout uses tables for the same reason.
/// - `.standaloneDocument` wraps the same fragment in a full page with a
///   viewport meta tag and a small responsive stylesheet, for saving to disk
///   or hosting.
///
/// The look is typographic rather than decorative: one large title, sentence
/// headings, a single quiet group for metrics with hairline dividers. The
/// markup is semantic on purpose: headings, lists, `<table>` with header
/// scopes, `<figure>`/`<figcaption>`, and visually hidden text for status and
/// change directions, so the exported card is accessible wherever it lands.
public struct HTMLRenderer: Sendable {
    public struct Options: Sendable {
        public enum Mode: Sendable {
            case emailFragment
            case standaloneDocument
        }

        public var mode: Mode
        /// Maximum card width in CSS pixels. 600 is the safe width for email.
        public var maxWidth: Int
        /// Inline images as `data:` URIs. When false, images are referenced
        /// by file name (`image-1.png`) for export alongside files.
        public var embedImages: Bool
        public var includeFooter: Bool
        /// BCP 47 language tag for the `lang` attribute.
        public var language: String
        public var locale: Locale
        /// Heading level of the card title, 1...5. Block headings use the next
        /// level. Raise it when embedding the fragment inside a page that
        /// already has its own `<h1>`, so the outline stays valid.
        public var baseHeadingLevel: Int

        public init(
            mode: Mode = .emailFragment,
            maxWidth: Int = 600,
            embedImages: Bool = true,
            includeFooter: Bool = true,
            language: String = "en",
            locale: Locale = .current,
            baseHeadingLevel: Int = 1
        ) {
            self.mode = mode
            self.maxWidth = maxWidth
            self.embedImages = embedImages
            self.includeFooter = includeFooter
            self.language = language
            self.locale = locale
            self.baseHeadingLevel = min(5, max(1, baseHeadingLevel))
        }

        public static let email = Options()
        public static let standalone = Options(mode: .standaloneDocument)
    }

    public var options: Options

    public init(options: Options = .email) {
        self.options = options
    }

    public func render(_ card: SnippetCard) -> String {
        let body = renderArticle(card)
        switch options.mode {
        case .emailFragment:
            return body
        case .standaloneDocument:
            return wrapDocument(body, card: card)
        }
    }

    /// File names used for images when `embedImages` is false, in block order.
    public static func imageFileNames(for card: SnippetCard) -> [(block: ImageBlock, fileName: String)] {
        card.imageBlocks.enumerated().map { index, block in
            (block, "image-\(index + 1).\(block.contentType.fileExtension)")
        }
    }

    /// Inline-styled equivalent of the common `.sr-only` class. Works in
    /// email clients that drop stylesheets.
    public static let visuallyHiddenStyle =
        "position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;border:0"

    /// Rounded numerals for metric values where the font is available
    /// (Apple Mail, Safari), falling back to the theme's stack elsewhere.
    static let roundedFontPrefix = "ui-rounded, 'SF Pro Rounded', "

    // MARK: Article

    private func renderArticle(_ card: SnippetCard) -> String {
        let theme = card.theme
        var html = ""
        let articleStyle = [
            "max-width:\(options.maxWidth)px", "margin:0 auto", "font-family:\(theme.fontFamily)",
            "font-size:15px", "line-height:1.47", "color:\(theme.text.hexString)",
            "background:\(theme.background.hexString)", "border:1px solid \(theme.border.hexString)",
            "border-radius:\(Int(theme.cornerRadius))px", "padding:28px", "box-sizing:border-box",
        ].joined(separator: ";")
        html += "<article lang=\"\(options.language.htmlEscaped)\" class=\"card\" style=\"\(articleStyle)\">\n"
        html += renderHeader(card)
        let imageNames = Dictionary(uniqueKeysWithValues: Self.imageFileNames(for: card).map { ($0.block.id, $0.fileName) })
        for block in card.blocks {
            switch block {
            case let .text(text): html += renderText(text, theme: theme)
            case let .metrics(metrics): html += renderMetrics(metrics, theme: theme)
            case let .image(image): html += renderImage(image, theme: theme, fileName: imageNames[image.id])
            }
        }
        if options.includeFooter {
            html += renderFooter(card)
        }
        html += "</article>"
        return html
    }

    private func renderHeader(_ card: SnippetCard) -> String {
        let theme = card.theme
        var html = "<header>\n"
        if !card.subtitle.isEmpty {
            html += "<p style=\"margin:0 0 6px;font-size:13px;color:\(theme.secondaryText.hexString)\">"
                + "\(card.subtitle.htmlEscaped)</p>\n"
        }
        let titleTag = "h\(options.baseHeadingLevel)"
        html += "<\(titleTag) style=\"margin:0 0 10px;font-size:28px;line-height:1.15;font-weight:700;"
            + "letter-spacing:-0.01em;color:\(theme.text.hexString)\">\(card.title.htmlEscaped)</\(titleTag)>\n"
        // The indicator is decorative; the words carry the status.
        html += "<p style=\"margin:0;font-size:13px;font-weight:500;color:\(theme.text.hexString)\">"
            + "<span aria-hidden=\"true\" style=\"color:\(theme.statusColor(for: card.status).hexString)\">\(card.status.glyph)</span> "
            + "<span style=\"\(Self.visuallyHiddenStyle)\">Status: </span>\(card.status.label.htmlEscaped)</p>\n"
        html += "</header>\n"
        return html
    }

    private func sectionHeading(_ text: String, theme: CardTheme, id: String) -> String {
        guard !text.isEmpty else { return "" }
        let style = "margin:0 0 8px;font-size:15px;line-height:1.3;font-weight:600;color:\(theme.text.hexString)"
        let tag = "h\(options.baseHeadingLevel + 1)"
        return "<\(tag) id=\"\(id)\" style=\"\(style)\">\(text.htmlEscaped)</\(tag)>\n"
    }

    private func sectionOpen(heading: String, id: UUID) -> String {
        let headingID = "h-\(id.uuidString.prefix(8).lowercased())"
        let labelled = heading.isEmpty ? "" : " aria-labelledby=\"\(headingID)\""
        return "<section\(labelled) style=\"margin:22px 0 0\">\n"
    }

    private func renderText(_ block: TextBlock, theme: CardTheme) -> String {
        guard !block.isEmpty else { return "" }
        let headingID = "h-\(block.id.uuidString.prefix(8).lowercased())"
        var html = sectionOpen(heading: block.heading, id: block.id)
        html += sectionHeading(block.heading, theme: theme, id: headingID)
        let fragments = block.fragments
        for (index, fragment) in fragments.enumerated() {
            let bottom = index == fragments.count - 1 ? "0" : "10px"
            switch fragment {
            case let .paragraph(text):
                let lines = text.htmlEscaped.replacingOccurrences(of: "\n", with: "<br>")
                html += "<p style=\"margin:0 0 \(bottom)\">\(lines)</p>\n"
            case let .bullets(items):
                html += "<ul style=\"margin:0 0 \(bottom);padding-left:20px\">\n"
                for item in items {
                    html += "<li style=\"margin:0 0 4px\">\(item.htmlEscaped)</li>\n"
                }
                html += "</ul>\n"
            }
        }
        html += "</section>\n"
        return html
    }

    private func renderMetrics(_ block: MetricsBlock, theme: CardTheme) -> String {
        guard !block.isEmpty else { return "" }
        let headingID = "h-\(block.id.uuidString.prefix(8).lowercased())"
        var html = sectionOpen(heading: block.heading, id: block.id)
        html += sectionHeading(block.heading, theme: theme, id: headingID)
        switch block.layout {
        case .tiles: html += renderTiles(block.metrics, theme: theme)
        case .table: html += renderTable(block, theme: theme)
        }
        html += "</section>\n"
        return html
    }

    private func changeMarkup(_ change: MetricChange, theme: CardTheme, fontSize: Int = 12) -> String {
        let color = theme.changeColor(for: change.sentiment).hexString
        let visible = change.text.isEmpty ? "" : " \(change.text.htmlEscaped)"
        return "<span style=\"font-size:\(fontSize)px;font-weight:500;color:\(color)\">"
            + "<span aria-hidden=\"true\">\(change.direction.glyph)\(visible)</span>"
            + "<span style=\"\(Self.visuallyHiddenStyle)\">\(change.accessibleDescription.htmlEscaped)</span></span>"
    }

    /// One quiet group: a single tinted surface, metrics separated by hairlines.
    private func renderTiles(_ metrics: [Metric], theme: CardTheme) -> String {
        let perRow = metrics.count == 4 ? 2 : min(3, max(metrics.count, 1))
        let divider = "1px solid \(theme.border.hexString)"
        var html = "<table role=\"presentation\" style=\"width:100%;border-collapse:separate;border-spacing:0;"
            + "background:\(theme.surface.hexString);border-radius:12px\">\n"
        for rowStart in stride(from: 0, to: metrics.count, by: perRow) {
            html += "<tr>\n"
            let row = metrics[rowStart ..< min(rowStart + perRow, metrics.count)]
            for (offset, metric) in row.enumerated() {
                var tileStyle = ["vertical-align:top", "width:\(100 / perRow)%", "padding:14px 16px"]
                if offset > 0 {
                    tileStyle.append("border-left:\(divider)")
                }
                if rowStart > 0 {
                    tileStyle.append("border-top:\(divider)")
                }
                html += "<td class=\"tile\" style=\"\(tileStyle.joined(separator: ";"))\" width=\"\(100 / perRow)%\">\n"
                html += "<p style=\"margin:0;font-size:12px;color:\(theme.secondaryText.hexString)\">"
                    + "\(metric.label.htmlEscaped)</p>\n"
                html += "<p style=\"margin:2px 0 0;font-family:\(Self.roundedFontPrefix)\(theme.fontFamily);font-size:28px;"
                    + "font-weight:600;line-height:1.15;color:\(theme.text.hexString)\">\(metric.value.htmlEscaped)</p>\n"
                if let change = metric.change {
                    html += "<p style=\"margin:4px 0 0\">\(changeMarkup(change, theme: theme))</p>\n"
                }
                html += "</td>\n"
            }
            // Keep the grid rectangular so dividers line up on a short last row.
            for _ in row.count ..< perRow {
                html += "<td style=\"border-top:\(divider)\" aria-hidden=\"true\"></td>\n"
            }
            html += "</tr>\n"
        }
        html += "</table>\n"
        return html
    }

    private func renderTable(_ block: MetricsBlock, theme: CardTheme) -> String {
        let hasChange = block.metrics.contains { $0.change != nil }
        let divider = "1px solid \(theme.border.hexString)"
        let head = "padding:0 0 6px;border-bottom:\(divider);font-size:12px;font-weight:400;"
            + "color:\(theme.secondaryText.hexString)"
        let cell = "padding:9px 0;border-bottom:\(divider);vertical-align:top"
        var html = "<table style=\"width:100%;border-collapse:collapse;font-size:15px\">\n"
        html += "<thead><tr>"
        html += "<th scope=\"col\" style=\"\(head);text-align:left\">Metric</th>"
        html += "<th scope=\"col\" style=\"\(head);text-align:right\">Value</th>"
        if hasChange {
            html += "<th scope=\"col\" style=\"\(head);text-align:right\">Change</th>"
        }
        html += "</tr></thead>\n<tbody>\n"
        for metric in block.metrics {
            html += "<tr>"
            html += "<th scope=\"row\" style=\"\(cell);text-align:left;font-weight:400\">\(metric.label.htmlEscaped)</th>"
            html += "<td style=\"\(cell);text-align:right;font-weight:600\">\(metric.value.htmlEscaped)</td>"
            if hasChange {
                html += "<td style=\"\(cell);text-align:right;white-space:nowrap\">"
                if let change = metric.change {
                    html += changeMarkup(change, theme: theme, fontSize: 13)
                }
                html += "</td>"
            }
            html += "</tr>\n"
        }
        html += "</tbody></table>\n"
        return html
    }

    private func renderImage(_ block: ImageBlock, theme: CardTheme, fileName: String?) -> String {
        let source = options.embedImages ? block.dataURI : (fileName ?? "image.png")
        let alt = block.isDecorative ? "" : block.altText.htmlEscaped
        var attributes = "src=\"\(source)\" alt=\"\(alt)\""
        if block.isDecorative {
            attributes += " role=\"presentation\""
        }
        if let size = block.pixelSize {
            attributes += " width=\"\(size.width)\" height=\"\(size.height)\""
        }
        var html = "<figure style=\"margin:22px 0 0\">\n"
        html += "<img \(attributes) style=\"display:block;max-width:100%;height:auto;border-radius:10px;"
            + "border:1px solid \(theme.border.hexString)\">\n"
        if !block.caption.isEmpty {
            html += "<figcaption style=\"margin:8px 0 0;font-size:12px;color:\(theme.secondaryText.hexString)\">"
                + "\(block.caption.htmlEscaped)</figcaption>\n"
        }
        html += "</figure>\n"
        return html
    }

    private func renderFooter(_ card: SnippetCard) -> String {
        let text = CardDateFormatting.footerText(for: card, locale: options.locale)
        return "<footer><p style=\"margin:24px 0 0;font-size:11px;color:\(card.theme.secondaryText.hexString)\">"
            + "\(text.htmlEscaped)</p></footer>\n"
    }

    private func wrapDocument(_ body: String, card: SnippetCard) -> String {
        let pageBackground = card.theme.isDark ? "#000000" : "#F5F5F7"
        return """
        <!doctype html>
        <html lang="\(options.language.htmlEscaped)">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(card.title.htmlEscaped)</title>
        <style>
        body { margin: 0; padding: 24px 16px; background: \(pageBackground); -webkit-text-size-adjust: 100%;
               -webkit-font-smoothing: antialiased; }
        img { max-width: 100%; height: auto; }
        @media (max-width: 480px) {
          body { padding: 12px 8px; }
          .card { padding: 20px !important; }
          .card td.tile { display: block; width: auto !important; border-left: none !important;
                          border-top: 1px solid \(card.theme.border.hexString); }
          .card tr:first-child td.tile:first-child { border-top: none; }
        }
        @media (prefers-reduced-motion: reduce) { * { transition: none !important; } }
        </style>
        </head>
        <body>
        <main>
        \(body)
        </main>
        </body>
        </html>
        """
    }
}
