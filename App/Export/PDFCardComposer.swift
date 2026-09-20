import AppKit
import CoreGraphics
import ReportCore
import SwiftUI

/// Writes the card as a vector PDF with real, selectable text and a logical
/// structure tree (tagged PDF): the title is a heading, sections are headings
/// and paragraphs, lists are lists, and images are figures carrying their
/// description as alternative text. That is what lets a screen reader read a
/// PDF as a document instead of a picture.
///
/// SwiftUI draws the pieces; Core Graphics places them and wraps each in its
/// tag. The pieces are the same views `CardView` is made of, laid out with the
/// same `CardStyle` spacing, so the PDF matches the PNG.
@MainActor
enum PDFCardComposer {
    fileprivate struct Element {
        var view: AnyView
        var tag: CGPDFTagType?
        var actualText: String?
        var alternativeText: String?
        var spacingBefore: CGFloat
    }

    static func data(for card: SnippetCard, width: CGFloat = 600, includeFooter: Bool = true) -> Data? {
        let contentWidth = width - CardStyle.padding * 2
        let typography = CardTypography(scale: card.textSize.scale)
        let elements = elements(for: card, typography: typography, includeFooter: includeFooter)

        // Measure every piece at the content width.
        var renderers: [(element: Element, renderer: ImageRenderer<AnyView>, size: CGSize)] = []
        for element in elements {
            let content = AnyView(
                element.view
                    .frame(width: contentWidth, alignment: .leading)
                    .environment(\.cardTypography, typography)
                    .environment(\.colorScheme, card.theme.isDark ? .dark : .light)
            )
            let renderer = ImageRenderer(content: content)
            renderer.proposedSize = ProposedViewSize(width: contentWidth, height: nil)
            var measured = CGSize.zero
            renderer.render { size, _ in measured = size }
            renderers.append((element, renderer, measured))
        }
        let contentHeight = renderers.reduce(CGFloat.zero) { $0 + $1.element.spacingBefore + $1.size.height }
        let pageHeight = (contentHeight + CardStyle.padding * 2).rounded(.up)

        let output = NSMutableData()
        guard let consumer = CGDataConsumer(data: output as CFMutableData) else { return nil }
        var mediaBox = CGRect(x: 0, y: 0, width: width, height: pageHeight)
        let info: [CFString: Any] = [
            kCGPDFContextTitle: card.title.isEmpty ? "Untitled" : card.title,
            kCGPDFContextAuthor: card.author,
            kCGPDFContextCreator: "Reporting Builder",
            kCGPDFContextSubject: card.subtitle,
        ]
        guard let pdf = CGContext(consumer: consumer, mediaBox: &mediaBox, info as CFDictionary) else { return nil }

        pdf.beginPDFPage(nil)
        drawPaper(for: card.theme, in: pdf, box: mediaBox)

        beginTag(.document, in: pdf, properties: [.languageText: "en"])
        var top = CardStyle.padding
        for item in renderers {
            top += item.element.spacingBefore
            pdf.saveGState()
            // PDF space starts at the bottom left; `top` is measured from the top.
            pdf.translateBy(x: CardStyle.padding, y: pageHeight - top - item.size.height)
            if let tag = item.element.tag {
                var properties: [CGPDFTagProperty: String] = [:]
                if let actualText = item.element.actualText {
                    properties[.actualText] = actualText
                }
                if let alternativeText = item.element.alternativeText {
                    properties[.alternativeText] = alternativeText
                }
                beginTag(tag, in: pdf, properties: properties)
                item.renderer.render { _, draw in draw(pdf) }
                CGPDFContextEndTag(pdf)
            } else {
                // Decorative content stays outside the structure tree, so it is skipped.
                item.renderer.render { _, draw in draw(pdf) }
            }
            pdf.restoreGState()
            top += item.size.height
        }
        CGPDFContextEndTag(pdf)

        pdf.endPDFPage()
        pdf.closePDF()
        return output as Data
    }

    /// Opens a structure element. Everything drawn until the matching end tag
    /// belongs to it.
    private static func beginTag(_ tag: CGPDFTagType, in pdf: CGContext, properties: [CGPDFTagProperty: String]) {
        var dictionary: [CFString: Any] = [:]
        for (key, value) in properties {
            dictionary[key.rawValue] = value
        }
        CGPDFContextBeginTag(pdf, tag, dictionary as CFDictionary)
    }

    private static func drawPaper(for theme: CardTheme, in pdf: CGContext, box: CGRect) {
        let path = CGPath(
            roundedRect: box.insetBy(dx: 0.5, dy: 0.5),
            cornerWidth: theme.cornerRadius,
            cornerHeight: theme.cornerRadius,
            transform: nil
        )
        pdf.addPath(path)
        pdf.setFillColor(theme.background.nsColor.cgColor)
        pdf.fillPath()
        pdf.addPath(path)
        pdf.setStrokeColor(theme.border.nsColor.cgColor)
        pdf.setLineWidth(1)
        pdf.strokePath()
    }

    // MARK: Structure

    private static func elements(for card: SnippetCard, typography: CardTypography, includeFooter: Bool) -> [Element] {
        let theme = card.theme
        var elements: [Element] = []

        if !card.subtitle.isEmpty {
            elements.append(Element(
                view: AnyView(Text(card.subtitle).font(typography.eyebrow).foregroundStyle(theme.secondaryText.color)),
                tag: .paragraph, spacingBefore: 0
            ))
        }
        elements.append(Element(
            view: AnyView(
                Text(card.title.isEmpty ? "Untitled" : card.title)
                    .font(typography.title).tracking(-0.3).foregroundStyle(theme.text.color)
                    .fixedSize(horizontal: false, vertical: true)
            ),
            tag: .header1, spacingBefore: card.subtitle.isEmpty ? 0 : 6
        ))
        elements.append(Element(
            view: AnyView(StatusLine(status: card.status, theme: theme)),
            tag: .paragraph, actualText: "Status: \(card.status.label)", spacingBefore: 10
        ))

        for block in card.blocks {
            switch block {
            case let .text(text) where !text.isEmpty: elements += textElements(text, theme: theme)
            case let .metrics(metrics) where !metrics.isEmpty: elements += metricsElements(metrics, theme: theme)
            case let .image(image): elements += imageElements(image, theme: theme, typography: typography)
            default: continue
            }
        }
        if includeFooter {
            elements.append(Element(
                view: AnyView(Text(CardDateFormatting.footerText(for: card)).font(typography.footer)
                    .foregroundStyle(theme.secondaryText.color)),
                tag: .paragraph, spacingBefore: 24
            ))
        }
        return elements
    }
}

extension PDFCardComposer {
    private static func textElements(_ text: TextBlock, theme: CardTheme) -> [Element] {
        var elements: [Element] = []
        var spacing = CardStyle.blockSpacing
        if !text.heading.isEmpty {
            elements.append(Element(
                view: AnyView(CardSectionHeading(text: text.heading, theme: theme)),
                tag: .header2,
                spacingBefore: spacing
            ))
            spacing = 8
        }
        for fragment in text.fragments {
            switch fragment {
            case let .paragraph(paragraph):
                elements.append(Element(
                    view: AnyView(CardParagraph(text: paragraph, theme: theme)),
                    tag: .paragraph,
                    spacingBefore: spacing
                ))
            case let .bullets(items):
                elements.append(Element(view: AnyView(CardBulletList(items: items, theme: theme)), tag: .list, spacingBefore: spacing))
            }
            spacing = 8
        }
        return elements
    }

    private static func metricsElements(_ metrics: MetricsBlock, theme: CardTheme) -> [Element] {
        var elements: [Element] = []
        var spacing = CardStyle.blockSpacing
        if !metrics.heading.isEmpty {
            elements.append(Element(
                view: AnyView(CardSectionHeading(text: metrics.heading, theme: theme)),
                tag: .header2,
                spacingBefore: spacing
            ))
            spacing = 8
        }
        // The visual is a grid; the reading is one sentence per metric.
        elements.append(Element(
            view: AnyView(MetricsContent(block: metrics, theme: theme)),
            tag: .paragraph,
            actualText: metrics.metrics.map(\.accessibleDescription).joined(separator: ". ") + ".",
            spacingBefore: spacing
        ))
        return elements
    }

    private static func imageElements(_ image: ImageBlock, theme: CardTheme, typography: CardTypography) -> [Element] {
        let picture = Element(
            view: AnyView(CardImage(block: image, theme: theme)),
            tag: image.isDecorative ? nil : .figure,
            alternativeText: image.isDecorative ? nil : image.altText,
            spacingBefore: CardStyle.blockSpacing
        )
        var elements = [picture]
        if !image.caption.isEmpty {
            elements.append(Element(
                view: AnyView(Text(image.caption).font(typography.caption).foregroundStyle(theme.secondaryText.color)),
                tag: .caption,
                spacingBefore: 8
            ))
        }
        return elements
    }
}

/// Prints the card through the standard macOS print panel, which also offers
/// Save as PDF, Mail PDF and the rest of the PDF menu.
@MainActor
enum CardPrinter {
    static func print(_ card: SnippetCard, width: CGFloat, includeFooter: Bool) {
        let hosting = NSHostingView(rootView: CardView(card: card, width: width, includeFooter: includeFooter).padding(12))
        hosting.frame = CGRect(origin: .zero, size: hosting.fittingSize)
        let info = (NSPrintInfo.shared.copy() as? NSPrintInfo) ?? NSPrintInfo.shared
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isHorizontallyCentered = true
        info.isVerticallyCentered = false
        let operation = NSPrintOperation(view: hosting, printInfo: info)
        operation.jobTitle = card.title.isEmpty ? "Card" : card.title
        operation.run()
    }
}
