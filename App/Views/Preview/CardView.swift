import AppKit
import Charts
import ReportCore
import SwiftUI

/// The visual card. Used by the live preview, by `ImageRenderer` for PNG
/// export and by the drag preview, so all three always agree.
///
/// Sizes are fixed points rather than Dynamic Type because the output is an
/// artifact with a known width, like a PDF. The editor around it uses
/// semantic fonts and follows the system text size.
struct CardView: View {
    let card: SnippetCard
    var width: CGFloat = 600
    var includeFooter = true

    private var theme: CardTheme {
        card.theme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ForEach(card.blocks) { block in
                blockView(block)
            }
            if includeFooter {
                footer
            }
        }
        .padding(24)
        .frame(width: width, alignment: .leading)
        .background(theme.background.color)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .stroke(theme.border.color, lineWidth: 1)
        )
        .environment(\.colorScheme, theme.isDark ? .dark : .light)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Card: \(card.title.isEmpty ? "Untitled" : card.title), \(card.status.label)")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !card.subtitle.isEmpty {
                Text(card.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.secondaryText.color)
            }
            Text(card.title.isEmpty ? "Untitled" : card.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(theme.text.color)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            StatusPill(status: card.status, theme: theme)
        }
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block {
        case let .text(text):
            if !text.isEmpty {
                TextBlockView(block: text, theme: theme)
            }
        case let .metrics(metrics):
            if !metrics.isEmpty {
                MetricsBlockView(block: metrics, theme: theme)
            }
        case let .image(image):
            ImageBlockView(block: image, theme: theme, maxWidth: width - 48)
        }
    }

    private var footer: some View {
        Text(CardDateFormatting.footerText(for: card))
            .font(.system(size: 11))
            .foregroundStyle(theme.secondaryText.color)
            .padding(.top, 16)
    }
}

// MARK: - Pieces

struct StatusPill: View {
    let status: ReportStatus
    let theme: CardTheme

    var body: some View {
        let colors = theme.statusColors(for: status)
        HStack(spacing: 5) {
            Text(status.glyph).font(.system(size: 10)).accessibilityHidden(true)
            Text("Status: \(status.label)").font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(colors.foreground.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(colors.background.color))
        .accessibilityElement(children: .combine)
    }
}

struct SectionHeading: View {
    let text: String
    let theme: CardTheme

    var body: some View {
        if !text.isEmpty {
            Text(text.uppercased())
                .font(.system(size: 12, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(theme.secondaryText.color)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

struct TextBlockView: View {
    let block: TextBlock
    let theme: CardTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeading(text: block.heading, theme: theme)
            ForEach(Array(block.fragments.enumerated()), id: \.offset) { _, fragment in
                switch fragment {
                case let .paragraph(text):
                    Text(text)
                        .font(.system(size: 15))
                        .foregroundStyle(theme.text.color)
                        .fixedSize(horizontal: false, vertical: true)
                case let .bullets(items):
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("•").accessibilityHidden(true)
                                Text(item).fixedSize(horizontal: false, vertical: true)
                            }
                            .font(.system(size: 15))
                            .foregroundStyle(theme.text.color)
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("List, \(items.count) items")
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct MetricsBlockView: View {
    let block: MetricsBlock
    let theme: CardTheme

    private var perRow: Int {
        block.metrics.count == 4 ? 2 : min(3, max(block.metrics.count, 1))
    }

    private var rows: [[Metric]] {
        stride(from: 0, to: block.metrics.count, by: perRow).map {
            Array(block.metrics[$0 ..< min($0 + perRow, block.metrics.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeading(text: block.heading, theme: theme)
            switch block.layout {
            case .tiles: tiles
            case .table: table
            }
        }
        .padding(.vertical, 8)
    }

    private var tiles: some View {
        VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 8) {
                    ForEach(row) { metric in
                        MetricTile(metric: metric, theme: theme)
                    }
                    if row.count < perRow {
                        ForEach(0 ..< (perRow - row.count), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private var hasChange: Bool {
        block.metrics.contains { $0.change != nil }
    }

    private var table: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Metric").frame(maxWidth: .infinity, alignment: .leading)
                Text("Value").frame(width: 120, alignment: .trailing)
                if hasChange {
                    Text("Change").frame(width: 100, alignment: .trailing)
                }
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(theme.secondaryText.color)
            .padding(.vertical, 6)
            .accessibilityHidden(true)
            Rectangle().fill(theme.border.color).frame(height: 1)
            ForEach(block.metrics) { metric in
                HStack {
                    Text(metric.label).font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity, alignment: .leading)
                    Text(metric.value).font(.system(size: 14)).frame(width: 120, alignment: .trailing)
                    if hasChange {
                        Text(metric.change?.display ?? "")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(metric.change.map { theme.changeColor(for: $0.sentiment).color } ?? theme.text.color)
                            .frame(width: 100, alignment: .trailing)
                    }
                }
                .foregroundStyle(theme.text.color)
                .padding(.vertical, 7)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(metric.accessibleDescription)
                Rectangle().fill(theme.border.color).frame(height: 1)
            }
        }
    }
}

struct MetricTile: View {
    let metric: Metric
    let theme: CardTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(metric.label)
                .font(.system(size: 12))
                .foregroundStyle(theme.secondaryText.color)
                .lineLimit(2)
            Text(metric.value)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(theme.text.color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack(spacing: 6) {
                if let change = metric.change {
                    Text(change.display)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.changeColor(for: change.sentiment).color)
                }
                Spacer(minLength: 0)
                if metric.trend.count >= 2 {
                    Sparkline(values: metric.trend, color: theme.accent.color)
                        .frame(width: 64, height: 22)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(theme.surface.color))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(theme.border.color, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var text = metric.accessibleDescription
        if let first = metric.trend.first, let last = metric.trend.last, metric.trend.count >= 2 {
            text += ", trend over \(metric.trend.count) points from \(NumberParsing.format(first)) to \(NumberParsing.format(last))"
        }
        return text
    }
}

/// Tiny trend line. Hidden from assistive tech because the tile's label
/// already describes the trend in words.
struct Sparkline: View {
    let values: [Double]
    let color: Color

    private var domain: ClosedRange<Double> {
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        return low == high ? (low - 1) ... (high + 1) : low ... high
    }

    var body: some View {
        Chart(Array(values.enumerated()), id: \.offset) { point in
            LineMark(x: .value("Point", point.offset), y: .value("Value", point.element))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartYScale(domain: domain)
        .accessibilityHidden(true)
    }
}

struct ImageBlockView: View {
    let block: ImageBlock
    let theme: CardTheme
    let maxWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let image = ImageCache.shared.image(for: block) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: maxWidth)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.border.color, lineWidth: 1))
                    .accessibilityLabel(block.altText)
                    .accessibilityHidden(block.isDecorative)
            }
            if !block.caption.isEmpty {
                Text(block.caption)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.secondaryText.color)
            }
        }
        .padding(.vertical, 8)
    }
}

/// Decoded images keyed by block identity and byte count, so the preview
/// does not re-decode on every render.
@MainActor
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, NSImage>()

    func image(for block: ImageBlock) -> NSImage? {
        let key = "\(block.id.uuidString)-\(block.imageData.count)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let image = NSImage(data: block.imageData) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}
