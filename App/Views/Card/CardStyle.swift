import ReportCore
import SwiftUI

/// Spacing and shape for the card, shared by the static renderer (`CardView`,
/// used for PNG and PDF export) and the editable canvas so the two cannot drift.
enum CardStyle {
    static let padding: CGFloat = 28
    static let blockSpacing: CGFloat = 22
    static let groupCornerRadius: CGFloat = 12
    static let imageCornerRadius: CGFloat = 10
    static let bodyLineSpacing: CGFloat = 3

    static func metricsPerRow(_ count: Int) -> Int {
        count == 4 ? 2 : min(3, max(count, 1))
    }
}

/// The card's type ramp. The look is typographic: hierarchy comes from size
/// and weight, not boxes, capitals or colour.
///
/// Sizes are points multiplied by the card's text size (`CardTextSize`), which
/// is how the large-print editions are made. They are fixed rather than
/// Dynamic Type because the card is an artifact with a known width; the app
/// chrome around it uses semantic fonts.
struct CardTypography: Equatable {
    var scale: CGFloat = 1

    var eyebrow: Font {
        .system(size: 13 * scale)
    }

    var title: Font {
        .system(size: 28 * scale, weight: .bold)
    }

    var status: Font {
        .system(size: 13 * scale, weight: .medium)
    }

    var statusGlyph: Font {
        .system(size: 9 * scale)
    }

    var heading: Font {
        .system(size: 15 * scale, weight: .semibold)
    }

    var body: Font {
        .system(size: 15 * scale)
    }

    var metricLabel: Font {
        .system(size: 12 * scale)
    }

    /// Rounded numerals, as in Fitness and Health.
    var metricValue: Font {
        .system(size: 28 * scale, weight: .semibold, design: .rounded)
    }

    var metricChange: Font {
        .system(size: 12 * scale, weight: .medium)
    }

    var tableValue: Font {
        .system(size: 15 * scale, weight: .semibold).monospacedDigit()
    }

    var tableChange: Font {
        .system(size: 13 * scale, weight: .medium).monospacedDigit()
    }

    var caption: Font {
        .system(size: 12 * scale)
    }

    var footer: Font {
        .system(size: 11 * scale)
    }

    /// Height of a single-line text field set in `pointSize`.
    ///
    /// AppKit-backed text fields do not reliably grow with a custom font: a
    /// 28-point value can be laid out in a 17-point-high field and lose its
    /// lower half. Every single-line field on the canvas states its height.
    func fieldHeight(_ pointSize: CGFloat) -> CGFloat {
        (pointSize * scale * 1.25).rounded(.up)
    }
}

extension EnvironmentValues {
    @Entry var cardTypography: CardTypography = .init()
}

extension View {
    /// Sets the type ramp for a card from its text size.
    func cardTypography(for card: SnippetCard) -> some View {
        environment(\.cardTypography, CardTypography(scale: card.textSize.scale))
    }
}

/// The paper the card sits on: padding, background, continuous corners and a
/// hairline. Exports get exactly this; on the canvas the paper is lifted off
/// the desk with a soft shadow.
struct CardSurface: ViewModifier {
    let theme: CardTheme
    var isElevated = false
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
        content
            .padding(CardStyle.padding)
            .background {
                // The shadow is cast by the paper alone. Applied to the whole
                // card it would also be cast by each text field.
                shape.fill(theme.background.color)
                    .shadow(color: .black.opacity(isElevated ? 0.14 : 0), radius: 18, y: 6)
            }
            // Increase Contrast (System Settings → Accessibility → Display) on the
            // canvas: the paper's edge is drawn in the text colour.
            .overlay(shape.strokeBorder(
                isElevated && contrast == .increased ? theme.text.color : theme.border.color,
                lineWidth: 1
            ))
            .environment(\.colorScheme, theme.isDark ? .dark : .light)
    }
}

/// Status as words with a small coloured indicator. The indicator's shape
/// differs per status, so nothing depends on colour alone.
struct StatusLine: View {
    let status: ReportStatus
    let theme: CardTheme
    @Environment(\.cardTypography) private var typography

    var body: some View {
        HStack(spacing: 6) {
            Text(status.glyph)
                .font(typography.statusGlyph)
                .foregroundStyle(theme.statusColor(for: status).color)
                .accessibilityHidden(true)
            Text(status.label)
                .font(typography.status)
                .foregroundStyle(theme.text.color)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Status: \(status.label)")
    }
}

/// Lays metrics out as one quiet group with hairline dividers. Generic over
/// the tile so the static and editable cards share the exact same grid.
struct MetricsGroup<Tile: View>: View {
    let count: Int
    let theme: CardTheme
    @ViewBuilder let tile: (Int) -> Tile

    private var perRow: Int {
        CardStyle.metricsPerRow(count)
    }

    private var rows: [[Int]] {
        stride(from: 0, to: count, by: perRow).map { Array($0 ..< min($0 + perRow, count)) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.element) { column, index in
                        tile(index)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(alignment: .leading) {
                                if column > 0 {
                                    Rectangle().fill(theme.border.color).frame(width: 1).padding(.vertical, 12)
                                }
                            }
                    }
                    ForEach(0 ..< (perRow - row.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
                .overlay(alignment: .top) {
                    if rowIndex > 0 {
                        Rectangle().fill(theme.border.color).frame(height: 1).padding(.horizontal, 16)
                    }
                }
            }
        }
        .background(theme.surface.color, in: RoundedRectangle(cornerRadius: CardStyle.groupCornerRadius, style: .continuous))
    }
}

/// Tiny trend line in the colour of the change, like Stocks. Hidden from
/// assistive tech because the tile's label describes the trend in words.
struct Sparkline: View {
    let values: [Double]
    let color: Color

    private var domain: ClosedRange<Double> {
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        return low == high ? (low - 1) ... (high + 1) : low ... high
    }

    var body: some View {
        SparklineShape(values: values, domain: domain)
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            .accessibilityHidden(true)
    }
}

private struct SparklineShape: Shape {
    let values: [Double]
    let domain: ClosedRange<Double>

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count >= 2 else { return path }
        let span = domain.upperBound - domain.lowerBound
        for (index, value) in values.enumerated() {
            let x = rect.minX + rect.width * CGFloat(index) / CGFloat(values.count - 1)
            let y = rect.maxY - rect.height * CGFloat((value - domain.lowerBound) / span)
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

extension Metric {
    /// One sentence for VoiceOver: label, value, change and trend.
    var spokenSummary: String {
        var text = accessibleDescription
        if let first = trend.first, let last = trend.last, trend.count >= 2 {
            text += ", trend over \(trend.count) points from \(NumberParsing.format(first)) to \(NumberParsing.format(last))"
        }
        return text
    }

    func trendColor(in theme: CardTheme) -> Color {
        change.map { theme.changeColor(for: $0.sentiment).color } ?? theme.secondaryText.color
    }
}

/// Decoded images keyed by block identity and byte count, so neither the
/// canvas nor the exporter re-decodes on every render.
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
