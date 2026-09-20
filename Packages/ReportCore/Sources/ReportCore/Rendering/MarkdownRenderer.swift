import Foundation

/// Renders a card as Markdown for chat and wiki tools.
public struct MarkdownRenderer: Sendable {
    public enum Flavor: Sendable {
        /// CommonMark with GFM tables. Suits Confluence, Notion, GitHub, Teams.
        case commonMark
        /// Slack "mrkdwn": bold with single asterisks, no headings or tables.
        case slack
    }

    public var flavor: Flavor
    public var includeFooter: Bool
    public var locale: Locale

    public init(flavor: Flavor = .commonMark, includeFooter: Bool = true, locale: Locale = .current) {
        self.flavor = flavor
        self.includeFooter = includeFooter
        self.locale = locale
    }

    public func render(_ card: SnippetCard) -> String {
        var lines: [String] = []
        lines.append(heading(card.title, level: 1))
        var meta: [String] = []
        if !card.subtitle.isEmpty {
            meta.append(card.subtitle.markdownEscaped)
        }
        meta.append("Status: \(card.status.glyph) \(card.status.label)")
        lines.append(meta.joined(separator: " · "))
        lines.append("")

        let imageNames = Dictionary(uniqueKeysWithValues: HTMLRenderer.imageFileNames(for: card).map { ($0.block.id, $0.fileName) })
        for block in card.blocks {
            switch block {
            case let .text(text): lines += renderText(text)
            case let .metrics(metrics): lines += renderMetrics(metrics)
            case let .image(image): lines += renderImage(image, fileName: imageNames[image.id] ?? "image.png")
            }
        }
        if includeFooter {
            lines.append("_\(CardDateFormatting.footerText(for: card, locale: locale).markdownEscaped)_")
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .newlines) + "\n"
    }

    private func heading(_ text: String, level: Int) -> String {
        switch flavor {
        case .commonMark: return String(repeating: "#", count: level) + " " + text.markdownEscaped
        case .slack: return "*\(text.replacingOccurrences(of: "*", with: ""))*"
        }
    }

    private func renderText(_ block: TextBlock) -> [String] {
        guard !block.isEmpty else { return [] }
        var lines: [String] = []
        if !block.heading.isEmpty {
            lines.append(heading(block.heading, level: 2))
        }
        for fragment in block.fragments {
            switch fragment {
            case let .paragraph(text):
                // Two trailing spaces force a line break in CommonMark; Slack breaks on a bare newline.
                let separator = flavor == .slack ? "\n" : "  \n"
                lines.append(text.components(separatedBy: "\n").map(\.markdownEscaped).joined(separator: separator))
            case let .bullets(items):
                let bullet = flavor == .slack ? "•" : "-"
                lines += items.map { "\(bullet) \($0.markdownEscaped)" }
            }
            lines.append("")
        }
        return lines
    }

    private func renderMetrics(_ block: MetricsBlock) -> [String] {
        guard !block.isEmpty else { return [] }
        var lines: [String] = []
        if !block.heading.isEmpty {
            lines.append(heading(block.heading, level: 2))
        }
        switch flavor {
        case .commonMark:
            let hasChange = block.metrics.contains { $0.change != nil }
            lines.append(hasChange ? "| Metric | Value | Change |" : "| Metric | Value |")
            lines.append(hasChange ? "|---|---|---|" : "|---|---|")
            for metric in block.metrics {
                var row = "| \(metric.label.markdownEscaped) | \(metric.value.markdownEscaped) |"
                if hasChange {
                    row += " \(metric.change?.display ?? "") |"
                }
                lines.append(row)
            }
        case .slack:
            for metric in block.metrics {
                var line = "• *\(metric.label.replacingOccurrences(of: "*", with: ""))*: \(metric.value)"
                if let change = metric.change {
                    line += " (\(change.display))"
                }
                lines.append(line)
            }
        }
        lines.append("")
        return lines
    }

    private func renderImage(_ block: ImageBlock, fileName: String) -> [String] {
        var lines: [String] = []
        let alt = block.isDecorative ? "" : block.altText
        switch flavor {
        case .commonMark: lines.append("![\(alt.markdownEscaped)](\(fileName))")
        case .slack: lines.append("_[Image: \(alt.isEmpty ? "decorative" : alt)]_")
        }
        if !block.caption.isEmpty {
            lines.append("_\(block.caption.markdownEscaped)_")
        }
        lines.append("")
        return lines
    }
}
