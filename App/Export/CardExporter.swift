import AppKit
import ReportCore
import SwiftUI

/// Turns a card into bytes in every supported format.
///
/// PNG rendering reuses the exact SwiftUI `CardView` shown in the preview,
/// so the exported image is guaranteed to match what the user saw.
@MainActor
enum CardExporter {
    static func pngData(
        for card: SnippetCard,
        width: CGFloat = 600,
        scale: CGFloat = 2,
        includeFooter: Bool = true
    ) -> Data? {
        let renderer = ImageRenderer(content: CardView(card: card, width: width, includeFooter: includeFooter))
        renderer.scale = scale
        renderer.isOpaque = false
        guard let cgImage = renderer.cgImage else { return nil }
        return NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
    }

    static func data(
        for card: SnippetCard,
        format: ExportFormat,
        preferences: ExportPreferences = ExportPreferences()
    ) throws -> Data {
        switch format {
        case .png:
            guard let data = pngData(
                for: card,
                width: preferences.width,
                scale: CGFloat(preferences.scale),
                includeFooter: preferences.includeFooter
            ) else {
                throw ExportError.renderFailed
            }
            return data
        case .html:
            var options = HTMLRenderer.Options.standalone
            options.includeFooter = preferences.includeFooter
            options.maxWidth = Int(preferences.width)
            return Data(HTMLRenderer(options: options).render(card).utf8)
        case .markdown:
            return Data(MarkdownRenderer(includeFooter: preferences.includeFooter).render(card).utf8)
        case .plainText:
            return Data(PlainTextRenderer(includeFooter: preferences.includeFooter).render(card).utf8)
        case .json:
            return try CardCodec.encode(card)
        }
    }

    /// Writes the card to `url`. Markdown exports also write referenced
    /// images next to the file so the relative links resolve.
    static func write(
        _ card: SnippetCard,
        format: ExportFormat,
        to url: URL,
        preferences: ExportPreferences = ExportPreferences()
    ) throws {
        try data(for: card, format: format, preferences: preferences).write(to: url, options: .atomic)
        if format == .markdown {
            let folder = url.deletingLastPathComponent()
            for (block, name) in HTMLRenderer.imageFileNames(for: card) {
                try block.imageData.write(to: folder.appending(path: name), options: .atomic)
            }
        }
    }

    static func suggestedFileName(for card: SnippetCard, format: ExportFormat) -> String {
        "\(card.title.fileNameSafe).\(format.fileExtension)"
    }
}
