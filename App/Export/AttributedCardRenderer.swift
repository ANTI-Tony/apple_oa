import AppKit
import ReportCore

/// Builds the rich-text representation (RTF/RTFD) used when pasting into
/// Mail, Notes, TextEdit and other AppKit text views.
///
/// Rich text is pasted onto the destination's own background, usually white,
/// so colours always come from the light palette regardless of the card theme.
/// Metrics become a real `NSTextTable`, images become attachments.
@MainActor
struct AttributedCardRenderer {
    var includeFooter = true

    private let palette = CardTheme.light
    private let bodyFont = NSFont.systemFont(ofSize: 13)

    func render(_ card: SnippetCard) -> NSAttributedString {
        let output = NSMutableAttributedString()
        if !card.subtitle.isEmpty {
            output.append(paragraph(card.subtitle, font: .systemFont(ofSize: 12), color: palette.secondaryText.nsColor, spacingAfter: 2))
        }
        output.append(paragraph(
            card.title.isEmpty ? "Untitled" : card.title,
            font: .boldSystemFont(ofSize: 20),
            color: palette.text.nsColor,
            spacingAfter: 6
        ))
        let statusColors = palette.statusColors(for: card.status)
        output.append(paragraph(
            "\(card.status.glyph) Status: \(card.status.label)",
            font: .boldSystemFont(ofSize: 12),
            color: statusColors.foreground.nsColor,
            spacingAfter: 12
        ))
        for block in card.blocks {
            switch block {
            case let .text(text): appendText(text, to: output)
            case let .metrics(metrics): appendMetrics(metrics, to: output)
            case let .image(image): appendImage(image, to: output)
            }
        }
        if includeFooter {
            output.append(paragraph(
                CardDateFormatting.footerText(for: card),
                font: .systemFont(ofSize: 10),
                color: palette.secondaryText.nsColor,
                spacingBefore: 10,
                spacingAfter: 0
            ))
        }
        return output
    }

    // MARK: Pieces

    private func paragraph(
        _ text: String,
        font: NSFont,
        color: NSColor,
        spacingBefore: CGFloat = 0,
        spacingAfter: CGFloat = 6,
        bullet: Bool = false
    ) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacingBefore = spacingBefore
        style.paragraphSpacing = spacingAfter
        if bullet {
            style.headIndent = 16
            style.firstLineHeadIndent = 0
            style.tabStops = [NSTextTab(textAlignment: .left, location: 16)]
        }
        return NSAttributedString(string: text + "\n", attributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: style,
        ])
    }

    private func sectionHeading(_ text: String) -> NSAttributedString {
        paragraph(
            text.uppercased(),
            font: .boldSystemFont(ofSize: 11),
            color: palette.secondaryText.nsColor,
            spacingBefore: 10,
            spacingAfter: 4
        )
    }

    private func appendText(_ block: TextBlock, to output: NSMutableAttributedString) {
        guard !block.isEmpty else { return }
        if !block.heading.isEmpty {
            output.append(sectionHeading(block.heading))
        }
        for fragment in block.fragments {
            switch fragment {
            case let .paragraph(text):
                output.append(paragraph(text, font: bodyFont, color: palette.text.nsColor))
            case let .bullets(items):
                for (index, item) in items.enumerated() {
                    output.append(paragraph(
                        "•\t\(item)",
                        font: bodyFont,
                        color: palette.text.nsColor,
                        spacingAfter: index == items.count - 1 ? 6 : 2,
                        bullet: true
                    ))
                }
            }
        }
    }

    private func appendMetrics(_ block: MetricsBlock, to output: NSMutableAttributedString) {
        guard !block.isEmpty else { return }
        if !block.heading.isEmpty {
            output.append(sectionHeading(block.heading))
        }

        let hasChange = block.metrics.contains { $0.change != nil }
        let table = NSTextTable()
        table.numberOfColumns = hasChange ? 3 : 2
        table.setContentWidth(100, type: .percentageValueType)
        table.collapsesBorders = true

        func cell(
            _ text: String,
            row: Int,
            column: Int,
            bold: Bool = false,
            color: NSColor,
            isHeader: Bool = false
        ) -> NSAttributedString {
            let textBlock = NSTextTableBlock(table: table, startingRow: row, rowSpan: 1, startingColumn: column, columnSpan: 1)
            textBlock.setWidth(1, type: .absoluteValueType, for: .border)
            textBlock.setBorderColor(palette.border.nsColor)
            textBlock.setWidth(5, type: .absoluteValueType, for: .padding)
            if isHeader {
                textBlock.backgroundColor = palette.surface.nsColor
            }
            let style = NSMutableParagraphStyle()
            style.textBlocks = [textBlock]
            let font = bold ? NSFont.boldSystemFont(ofSize: 12) : NSFont.systemFont(ofSize: 12)
            return NSAttributedString(string: text + "\n", attributes: [
                .font: font, .foregroundColor: color, .paragraphStyle: style,
            ])
        }

        output.append(cell("Metric", row: 0, column: 0, bold: true, color: palette.secondaryText.nsColor, isHeader: true))
        output.append(cell("Value", row: 0, column: 1, bold: true, color: palette.secondaryText.nsColor, isHeader: true))
        if hasChange {
            output.append(cell("Change", row: 0, column: 2, bold: true, color: palette.secondaryText.nsColor, isHeader: true))
        }
        for (index, metric) in block.metrics.enumerated() {
            let row = index + 1
            output.append(cell(metric.label, row: row, column: 0, bold: true, color: palette.text.nsColor))
            output.append(cell(metric.value, row: row, column: 1, color: palette.text.nsColor))
            if hasChange {
                let color = metric.change.map { palette.changeColor(for: $0.sentiment).nsColor } ?? palette.text.nsColor
                output.append(cell(metric.change?.display ?? "", row: row, column: 2, bold: true, color: color))
            }
        }
        output.append(paragraph("", font: .systemFont(ofSize: 4), color: .clear, spacingAfter: 6))
    }

    private func appendImage(_ block: ImageBlock, to output: NSMutableAttributedString) {
        guard let image = NSImage(data: block.imageData) else { return }
        let wrapper = FileWrapper(regularFileWithContents: block.imageData)
        wrapper.preferredFilename = block.fileName ?? "image.\(block.contentType.fileExtension)"
        let attachment = NSTextAttachment(fileWrapper: wrapper)
        let maxWidth: CGFloat = 540
        let scale = min(1, maxWidth / max(image.size.width, 1))
        attachment.bounds = CGRect(x: 0, y: 0, width: image.size.width * scale, height: image.size.height * scale)
        let attachmentString = NSMutableAttributedString(attachment: attachment)
        attachmentString.append(NSAttributedString(string: "\n"))
        output.append(attachmentString)
        if !block.caption.isEmpty {
            output.append(paragraph(block.caption, font: .systemFont(ofSize: 12), color: palette.secondaryText.nsColor))
        }
    }
}
