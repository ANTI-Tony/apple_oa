import Foundation

/// One thing a screen reader would say, tied to the block it comes from.
public struct SpokenSegment: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable {
        case heading, status, text, list, metric, image, footer
        /// Something the listener does not get: an image nobody described.
        case gap
    }

    public var id: Int
    public var kind: Kind
    public var text: String
    public var blockID: UUID?

    public init(id: Int, kind: Kind, text: String, blockID: UUID? = nil) {
        self.id = id
        self.kind = kind
        self.text = text
        self.blockID = blockID
    }
}

/// Renders a card as the sequence of phrases a screen reader announces.
///
/// The app speaks this aloud so an author can hear the card the way a blind
/// colleague will: headings announced as headings, list lengths, metric
/// changes in words, image descriptions, and the silence where a description
/// is missing. It mirrors the semantics of the HTML output, not VoiceOver's
/// exact wording, which varies by app and verbosity setting.
public struct SpokenRenderer: Sendable {
    public var includeFooter: Bool
    public var locale: Locale

    public init(includeFooter: Bool = true, locale: Locale = .current) {
        self.includeFooter = includeFooter
        self.locale = locale
    }

    public func segments(for card: SnippetCard) -> [SpokenSegment] {
        var builder = Builder()
        if !card.subtitle.isEmpty {
            builder.add(.text, card.subtitle)
        }
        builder.add(.heading, "Heading level 1. \(card.title.isEmpty ? "Untitled" : card.title)")
        builder.add(.status, "Status: \(card.status.label)")

        for block in card.blocks {
            switch block {
            case let .text(text): Self.speak(text, into: &builder)
            case let .metrics(metrics): Self.speak(metrics, into: &builder)
            case let .image(image): Self.speak(image, into: &builder)
            }
        }
        if includeFooter {
            builder.add(.footer, CardDateFormatting.footerText(for: card, locale: locale))
        }
        return builder.segments
    }

    /// The whole narration as one string, one phrase per line.
    public func script(for card: SnippetCard) -> String {
        segments(for: card).map(\.text).joined(separator: "\n")
    }

    private static func speak(_ text: TextBlock, into builder: inout Builder) {
        guard !text.isEmpty else { return }
        if !text.heading.isEmpty {
            builder.add(.heading, "Heading level 2. \(text.heading)", block: text.id)
        }
        for fragment in text.fragments {
            switch fragment {
            case let .paragraph(paragraph):
                builder.add(.text, paragraph.replacingOccurrences(of: "\n", with: ". "), block: text.id)
            case let .bullets(items):
                builder.add(.list, "List, \(items.count) \(items.count == 1 ? "item" : "items").", block: text.id)
                for item in items {
                    builder.add(.list, item, block: text.id)
                }
            }
        }
    }

    private static func speak(_ metrics: MetricsBlock, into builder: inout Builder) {
        guard !metrics.isEmpty else { return }
        if !metrics.heading.isEmpty {
            builder.add(.heading, "Heading level 2. \(metrics.heading)", block: metrics.id)
        }
        for metric in metrics.metrics {
            let label = metric.label.isEmpty ? "Unlabelled number" : metric.label
            var phrase = "\(label): \(metric.value)"
            if let change = metric.change {
                phrase += ", \(change.accessibleDescription)"
            }
            builder.add(.metric, phrase, block: metrics.id)
        }
    }

    private static func speak(_ image: ImageBlock, into builder: inout Builder) {
        // A decorative image is skipped, exactly as a screen reader skips it.
        guard !image.isDecorative else { return }
        if image.hasAcceptableAltText {
            builder.add(.image, "Image. \(image.altText)", block: image.id)
        } else {
            builder.add(.gap, "Image. No description.", block: image.id)
        }
        if !image.caption.isEmpty {
            builder.add(.text, image.caption, block: image.id)
        }
    }

    private struct Builder {
        var segments: [SpokenSegment] = []

        mutating func add(_ kind: SpokenSegment.Kind, _ text: String, block: UUID? = nil) {
            segments.append(SpokenSegment(id: segments.count, kind: kind, text: text, blockID: block))
        }
    }
}
