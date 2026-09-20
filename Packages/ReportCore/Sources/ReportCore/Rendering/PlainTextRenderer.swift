import Foundation

/// Renders a card as plain text for Messages, SMS-style tools and as the
/// lowest-common-denominator pasteboard representation.
public struct PlainTextRenderer: Sendable {
    public var includeFooter: Bool
    public var locale: Locale

    public init(includeFooter: Bool = true, locale: Locale = .current) {
        self.includeFooter = includeFooter
        self.locale = locale
    }

    public func render(_ card: SnippetCard) -> String {
        var lines: [String] = [card.title.uppercased()]
        if !card.subtitle.isEmpty {
            lines.append(card.subtitle)
        }
        lines.append("Status: \(card.status.label)")
        lines.append("")
        for block in card.blocks {
            lines += render(block)
        }
        if includeFooter {
            lines.append(CardDateFormatting.footerText(for: card, locale: locale))
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .newlines) + "\n"
    }

    private func render(_ block: Block) -> [String] {
        switch block {
        case let .text(text): render(text)
        case let .metrics(metrics): render(metrics)
        case let .image(image): render(image)
        }
    }

    private func render(_ block: TextBlock) -> [String] {
        guard !block.isEmpty else { return [] }
        var lines: [String] = []
        if !block.heading.isEmpty {
            lines.append(block.heading.uppercased())
        }
        for fragment in block.fragments {
            switch fragment {
            case let .paragraph(paragraph): lines.append(paragraph)
            case let .bullets(items): lines += items.map { "- \($0)" }
            }
        }
        lines.append("")
        return lines
    }

    private func render(_ block: MetricsBlock) -> [String] {
        guard !block.isEmpty else { return [] }
        var lines: [String] = []
        if !block.heading.isEmpty {
            lines.append(block.heading.uppercased())
        }
        for metric in block.metrics {
            var line = "\(metric.label): \(metric.value)"
            if let change = metric.change {
                line += " (\(change.accessibleDescription))"
            }
            lines.append(line)
        }
        lines.append("")
        return lines
    }

    private func render(_ block: ImageBlock) -> [String] {
        var lines = ["[Image: \(block.isDecorative ? "decorative" : block.altText)]"]
        if !block.caption.isEmpty {
            lines.append(block.caption)
        }
        lines.append("")
        return lines
    }
}
