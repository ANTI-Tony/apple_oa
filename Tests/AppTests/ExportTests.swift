import AppKit
import Foundation
import ReportCore
import Testing
@testable import ReportingBuilder

@MainActor
@Suite("Export and pasteboard")
struct ExportTests {
    private let card = SampleContent.weeklyStatus()

    /// A private pasteboard so tests never clobber the user's clipboard.
    private func scratchPasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("com.tonywen.reportingbuilder.tests.\(UUID().uuidString)"))
    }

    @Test("PNG export renders a real image at the requested scale")
    func png() throws {
        let data = try #require(CardExporter.pngData(for: card, width: 600, scale: 2))
        #expect(ImageContentType.detect(from: data) == .png)
        let rep = try #require(NSBitmapImageRep(data: data))
        #expect(rep.pixelsWide == 1200)
        #expect(rep.pixelsHigh > 400)
    }

    @Test("Every export format produces non-empty data")
    func allFormats() throws {
        for format in ExportFormat.allCases {
            let data = try CardExporter.data(for: card, format: format)
            #expect(!data.isEmpty, "\(format)")
        }
        let html = try #require(try String(data: CardExporter.data(for: card, format: .html), encoding: .utf8))
        #expect(html.contains("<title>Weekly status</title>"))
        let json = try CardExporter.data(for: card, format: .json)
        #expect(try CardCodec.decodeCard(json).title == card.title)
    }

    @Test("Markdown export writes referenced images next to the file")
    func markdownWritesImages() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "rb-export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "card.md")
        try CardExporter.write(card, format: .markdown, to: url)
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "image-1.png").path))
    }

    @Test("Suggested file names are filesystem safe")
    func fileNames() {
        var tricky = card
        tricky.title = "Q3 / plan: \"final\"?"
        #expect(CardExporter.suggestedFileName(for: tricky, format: .png) == "Q3-plan-final.png")
        tricky.title = ""
        #expect(CardExporter.suggestedFileName(for: tricky, format: .html) == "card.html")
    }

    @Test("Copy for Email writes rich text, HTML and plain text together")
    func richCopy() throws {
        let pasteboard = scratchPasteboard()
        try PasteboardWriter.copy(card, variant: .rich, pasteboard: pasteboard)
        let types = Set(pasteboard.types ?? [])
        #expect(types.contains(.rtfd))
        #expect(types.contains(.rtf))
        #expect(types.contains(.html))
        #expect(types.contains(.string))
        let html = try #require(pasteboard.string(forType: .html))
        #expect(html.hasPrefix("<article"))
        #expect(html.contains("alt=\"Sprint 14 burndown"))
        let plain = try #require(pasteboard.string(forType: .string))
        #expect(plain.hasPrefix("WEEKLY STATUS"))
    }

    @Test("Copy as Image writes PNG and TIFF")
    func imageCopy() throws {
        let pasteboard = scratchPasteboard()
        try PasteboardWriter.copy(card, variant: .image, pasteboard: pasteboard)
        #expect(pasteboard.data(forType: .png) != nil)
        #expect(pasteboard.data(forType: .tiff) != nil)
    }

    @Test("Text variants write the matching renderer output")
    func textVariants() throws {
        let pasteboard = scratchPasteboard()
        try PasteboardWriter.copy(card, variant: .slack, pasteboard: pasteboard)
        let slack = try #require(pasteboard.string(forType: .string))
        #expect(slack.hasPrefix("*Weekly status*"))
        #expect(!slack.contains("|---"))

        try PasteboardWriter.copy(card, variant: .markdown, pasteboard: pasteboard)
        #expect(pasteboard.string(forType: .string)?.hasPrefix("# Weekly status") == true)

        try PasteboardWriter.copy(card, variant: .html, pasteboard: pasteboard)
        #expect(pasteboard.string(forType: .string)?.hasPrefix("<!doctype html>") == true)
    }

    @Test("Rich text renderer includes title, status, metrics table and image attachment")
    func attributed() {
        let attributed = AttributedCardRenderer().render(card)
        let text = attributed.string
        #expect(text.contains("Weekly status"))
        #expect(text.contains("Status: On track"))
        #expect(text.contains("Velocity"))
        #expect(text.contains("\u{FFFC}"), "image attachment present")
        var hasTable = false
        attributed.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: attributed.length)) { value, _, _ in
            if let style = value as? NSParagraphStyle, !style.textBlocks.isEmpty {
                hasTable = true
            }
        }
        #expect(hasTable)
    }
}
