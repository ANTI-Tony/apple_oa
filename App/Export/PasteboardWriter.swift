import AppKit
import ReportCore

/// The ways a card can be copied. Each variant targets the tools that best
/// consume it; see docs/EXPORT_COMPATIBILITY.md for the paste matrix.
enum CopyVariant: String, CaseIterable, Identifiable {
    /// Rich text + HTML + plain text in one clipboard entry. Mail and Notes
    /// take the rich text (with images), Slack and web apps take the HTML,
    /// everything else falls back to plain text.
    case rich
    case image
    case markdown
    case slack
    case plain
    case html

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .rich: "Copy for Email"
        case .image: "Copy as Image"
        case .markdown: "Copy as Markdown"
        case .slack: "Copy for Slack"
        case .plain: "Copy as Plain Text"
        case .html: "Copy HTML Source"
        }
    }

    var symbolName: String {
        switch self {
        case .rich: "envelope"
        case .image: "photo"
        case .markdown: "number"
        case .slack: "bubble.left.and.bubble.right"
        case .plain: "text.alignleft"
        case .html: "chevron.left.forwardslash.chevron.right"
        }
    }

    var confirmation: String {
        switch self {
        case .rich: "Copied. Paste into Mail, Notes or Slack."
        case .image: "Copied as an image."
        case .markdown: "Copied as Markdown."
        case .slack: "Copied in Slack format."
        case .plain: "Copied as plain text."
        case .html: "Copied HTML source."
        }
    }
}

/// Writes a card to a pasteboard in one or more representations.
@MainActor
enum PasteboardWriter {
    static func copy(
        _ card: SnippetCard,
        variant: CopyVariant,
        preferences: ExportPreferences = ExportPreferences(),
        pasteboard: NSPasteboard = .general
    ) throws {
        pasteboard.clearContents()
        switch variant {
        case .rich:
            var options = HTMLRenderer.Options.email
            options.includeFooter = preferences.includeFooter
            let html = HTMLRenderer(options: options).render(card)
            let plain = PlainTextRenderer(includeFooter: preferences.includeFooter).render(card)
            let attributed = AttributedCardRenderer(includeFooter: preferences.includeFooter).render(card)
            let range = NSRange(location: 0, length: attributed.length)
            let item = NSPasteboardItem()
            if let rtfd = attributed.rtfd(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]) {
                item.setData(rtfd, forType: .rtfd)
            }
            if let rtf = attributed.rtf(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
                item.setData(rtf, forType: .rtf)
            }
            item.setString(html, forType: .html)
            item.setString(plain, forType: .string)
            pasteboard.writeObjects([item])

        case .image:
            guard let png = CardExporter.pngData(
                for: card,
                scale: CGFloat(preferences.scale),
                includeFooter: preferences.includeFooter
            ),
                let image = NSImage(data: png) else {
                throw ExportError.renderFailed
            }
            let item = NSPasteboardItem()
            item.setData(png, forType: .png)
            if let tiff = image.tiffRepresentation {
                item.setData(tiff, forType: .tiff)
            }
            pasteboard.writeObjects([item])

        case .markdown:
            pasteboard.setString(MarkdownRenderer(includeFooter: preferences.includeFooter).render(card), forType: .string)

        case .slack:
            pasteboard.setString(MarkdownRenderer(flavor: .slack, includeFooter: preferences.includeFooter).render(card), forType: .string)

        case .plain:
            pasteboard.setString(PlainTextRenderer(includeFooter: preferences.includeFooter).render(card), forType: .string)

        case .html:
            var options = HTMLRenderer.Options.standalone
            options.includeFooter = preferences.includeFooter
            pasteboard.setString(HTMLRenderer(options: options).render(card), forType: .string)
        }
    }
}
