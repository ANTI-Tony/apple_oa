import AppKit
import ReportCore
import SwiftUI

/// The finished card, not editable. `ImageRenderer` turns this into the PNG
/// for export, Copy as Image, sharing and dragging. It is built from the same
/// pieces and constants as the canvas (`CardStyle`), so what is exported is
/// what was on screen.
struct CardView: View {
    let card: SnippetCard
    var width: CGFloat = 600
    var includeFooter = true

    private var theme: CardTheme {
        card.theme
    }

    /// The root sets the type ramp for its subtree, so it computes its own.
    private var typography: CardTypography {
        CardTypography(scale: card.textSize.scale)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ForEach(card.blocks) { block in
                blockView(block)
            }
            if includeFooter {
                Text(CardDateFormatting.footerText(for: card))
                    .font(typography.footer)
                    .foregroundStyle(theme.secondaryText.color)
                    .padding(.top, 24)
            }
        }
        .frame(width: width - CardStyle.padding * 2, alignment: .leading)
        .modifier(CardSurface(theme: theme))
        .cardTypography(for: card)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Card: \(card.title.isEmpty ? "Untitled" : card.title), \(card.status.label)")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !card.subtitle.isEmpty {
                Text(card.subtitle)
                    .font(typography.eyebrow)
                    .foregroundStyle(theme.secondaryText.color)
                    .padding(.bottom, 6)
            }
            Text(card.title.isEmpty ? "Untitled" : card.title)
                .font(typography.title)
                .tracking(-0.3)
                .foregroundStyle(theme.text.color)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 10)
            StatusLine(status: card.status, theme: theme)
        }
    }

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block {
        case let .text(text):
            if !text.isEmpty {
                TextBlockView(block: text, theme: theme).padding(.top, CardStyle.blockSpacing)
            }
        case let .metrics(metrics):
            if !metrics.isEmpty {
                MetricsBlockView(block: metrics, theme: theme).padding(.top, CardStyle.blockSpacing)
            }
        case let .image(image):
            ImageBlockView(block: image, theme: theme).padding(.top, CardStyle.blockSpacing)
        }
    }
}

// MARK: - Blocks

struct CardSectionHeading: View {
    @Environment(\.cardTypography) private var typography
    let text: String
    let theme: CardTheme

    var body: some View {
        if !text.isEmpty {
            Text(text)
                .font(typography.heading)
                .foregroundStyle(theme.text.color)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

struct CardParagraph: View {
    @Environment(\.cardTypography) private var typography
    let text: String
    let theme: CardTheme

    var body: some View {
        Text(text)
            .font(typography.body)
            .lineSpacing(CardStyle.bodyLineSpacing)
            .foregroundStyle(theme.text.color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct CardBulletList: View {
    @Environment(\.cardTypography) private var typography
    let items: [String]
    let theme: CardTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("•").accessibilityHidden(true)
                    Text(item).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .font(typography.body)
        .lineSpacing(CardStyle.bodyLineSpacing)
        .foregroundStyle(theme.text.color)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("List, \(items.count) items")
    }
}

struct TextBlockView: View {
    let block: TextBlock
    let theme: CardTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CardSectionHeading(text: block.heading, theme: theme)
            ForEach(Array(block.fragments.enumerated()), id: \.offset) { _, fragment in
                switch fragment {
                case let .paragraph(text): CardParagraph(text: text, theme: theme)
                case let .bullets(items): CardBulletList(items: items, theme: theme)
                }
            }
        }
    }
}

struct MetricsBlockView: View {
    let block: MetricsBlock
    let theme: CardTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CardSectionHeading(text: block.heading, theme: theme)
            MetricsContent(block: block, theme: theme)
        }
    }
}

/// The metrics themselves, without the heading: a group of tiles or a table.
struct MetricsContent: View {
    let block: MetricsBlock
    let theme: CardTheme

    private var hasChange: Bool {
        block.metrics.contains { $0.change != nil }
    }

    var body: some View {
        switch block.layout {
        case .tiles:
            MetricsGroup(count: block.metrics.count, theme: theme) { index in
                MetricTile(metric: block.metrics[index], theme: theme)
            }
        case .table:
            VStack(spacing: 0) {
                ForEach(block.metrics) { metric in
                    MetricTableRow(metric: metric, theme: theme, showsChange: hasChange)
                    Rectangle().fill(theme.border.color).frame(height: 1)
                }
            }
        }
    }
}

struct MetricTile: View {
    @Environment(\.cardTypography) private var typography
    let metric: Metric
    let theme: CardTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(metric.label)
                .font(typography.metricLabel)
                .foregroundStyle(theme.secondaryText.color)
                .lineLimit(2)
            Text(metric.value)
                .font(typography.metricValue)
                .foregroundStyle(theme.text.color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack(spacing: 6) {
                if let change = metric.change {
                    Text(change.display)
                        .font(typography.metricChange)
                        .foregroundStyle(theme.changeColor(for: change.sentiment).color)
                }
                Spacer(minLength: 0)
                if metric.trend.count >= 2 {
                    Sparkline(values: metric.trend, color: metric.trendColor(in: theme))
                        .frame(width: 52, height: 16)
                }
            }
            .frame(minHeight: 16)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metric.spokenSummary)
        .trendAudioGraph(for: metric)
    }
}

struct MetricTableRow: View {
    @Environment(\.cardTypography) private var typography
    let metric: Metric
    let theme: CardTheme
    let showsChange: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(metric.label)
                .font(typography.body)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(metric.value)
                .font(typography.tableValue)
            if showsChange {
                Text(metric.change?.display ?? "")
                    .font(typography.tableChange)
                    .foregroundStyle(metric.change.map { theme.changeColor(for: $0.sentiment).color } ?? theme.text.color)
                    .frame(width: 84, alignment: .trailing)
            }
        }
        .foregroundStyle(theme.text.color)
        .padding(.vertical, 9)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metric.accessibleDescription)
    }
}

struct ImageBlockView: View {
    @Environment(\.cardTypography) private var typography
    let block: ImageBlock
    let theme: CardTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CardImage(block: block, theme: theme)
            if !block.caption.isEmpty {
                Text(block.caption)
                    .font(typography.caption)
                    .foregroundStyle(theme.secondaryText.color)
            }
        }
    }
}

/// The picture alone, with its description for VoiceOver.
struct CardImage: View {
    let block: ImageBlock
    let theme: CardTheme

    var body: some View {
        if let image = ImageCache.shared.image(for: block) {
            let shape = RoundedRectangle(cornerRadius: CardStyle.imageCornerRadius, style: .continuous)
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(shape)
                .overlay(shape.strokeBorder(theme.border.color, lineWidth: 1))
                .accessibilityLabel(block.altText)
                .accessibilityHidden(block.isDecorative)
        }
    }
}
