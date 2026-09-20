import AppKit
import Foundation
import ReportCore
import Testing
@testable import ReportingBuilder

@MainActor
@Suite("Ingestion")
struct IngestionTests {
    private static let onePixelPNG = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==")!

    private func scratchPasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("com.tonywen.reportingbuilder.tests.\(UUID().uuidString)"))
    }

    private func bitmap(width: Int, height: Int, format: NSBitmapImageRep.FileType) -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        return rep.representation(using: format, properties: [:])!
    }

    @Test("Small PNG and JPEG pass through untouched")
    func passthrough() throws {
        let png = try #require(ImageImport.normalise(Self.onePixelPNG))
        #expect(png.type == .png)
        #expect(png.data == Self.onePixelPNG)
        #expect(png.size == PixelSize(width: 1, height: 1))

        let jpeg = bitmap(width: 40, height: 30, format: .jpeg)
        let normalised = try #require(ImageImport.normalise(jpeg))
        #expect(normalised.type == .jpeg)
        #expect(normalised.size == PixelSize(width: 40, height: 30))
    }

    @Test("TIFF is converted to PNG and oversized images are downscaled")
    func conversion() throws {
        let tiff = bitmap(width: 3200, height: 400, format: .tiff)
        let normalised = try #require(ImageImport.normalise(tiff))
        #expect(normalised.type == .png)
        #expect(normalised.size.width == ImageImport.maxPixelWidth)
        #expect(normalised.size.height == 200)
        #expect(ImageContentType.detect(from: normalised.data) == .png)
    }

    @Test("Garbage is rejected")
    func garbage() {
        #expect(ImageImport.normalise(Data("not an image".utf8)) == nil)
        #expect(ImageImport.imageBlock(from: Data()) == nil)
    }

    @Test("Smart paste classifies images, tables and prose")
    func paste() {
        let pasteboard = scratchPasteboard()

        pasteboard.clearContents()
        pasteboard.setData(Self.onePixelPNG, forType: .png)
        guard case .image = PasteIngestor.read(from: pasteboard) else {
            Issue.record("PNG on the pasteboard should become an image block")
            return
        }

        pasteboard.clearContents()
        pasteboard.setString("Velocity\t42\nOpen bugs\t12\nCoverage\t81%", forType: .string)
        guard case let .metrics(result, _) = PasteIngestor.read(from: pasteboard) else {
            Issue.record("Tab separated cells should become metrics")
            return
        }
        #expect(result.metrics.count == 3)

        pasteboard.clearContents()
        pasteboard.setString("We shipped the pilot this week and the team is happy.", forType: .string)
        guard case .text = PasteIngestor.read(from: pasteboard) else {
            Issue.record("Prose should stay text")
            return
        }

        pasteboard.clearContents()
        #expect(PasteIngestor.read(from: pasteboard) == nil)
    }

    @Test("Text drops become the right block type")
    func textBlocks() {
        let metrics = DropIngestor.blocks(fromText: "label,value\nVelocity,42\nBugs,3")
        #expect(metrics.first?.kind == .metrics)
        let text = DropIngestor.blocks(fromText: "Just a note.")
        #expect(text.first?.kind == .text)
        #expect(DropIngestor.blocks(fromText: "   ").isEmpty)
    }
}

@Suite("Configuration")
struct ConfigurationTests {
    @Test("Info.plist values flow from xcconfig")
    func infoPlist() {
        #expect(AppConfiguration.version == "0.1.0")
        #expect(!AppConfiguration.build.isEmpty)
        #expect(["Debug", "Release"].contains(AppConfiguration.buildFlavor))
        #expect(AppConfiguration.isEnabled(.sampleContent))
        #expect(AppConfiguration.isEnabled(.visionAssist))
    }

    @MainActor
    @Test("Preferences persist through UserDefaults with sane defaults")
    func preferences() throws {
        let suite = "com.tonywen.reportingbuilder.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = UserPreferences(defaults: defaults)
        #expect(preferences.exportScale == 2)
        #expect(preferences.includeFooter)
        #expect(preferences.defaultTheme == .light)
        preferences.exportScale = 3
        preferences.includeFooter = false
        preferences.defaultThemeID = CardTheme.dark.id
        let reloaded = UserPreferences(defaults: defaults)
        #expect(reloaded.exportScale == 3)
        #expect(!reloaded.includeFooter)
        #expect(reloaded.defaultTheme == .dark)
    }
}

@Suite("Window layout")
struct WindowLayoutTests {
    @Test("Breakpoints map widths to layouts")
    func breakpoints() {
        #expect(WindowLayout.forWidth(1500) == .wide)
        #expect(WindowLayout.forWidth(WindowLayout.mediumBreakpoint) == .wide)
        #expect(WindowLayout.forWidth(WindowLayout.mediumBreakpoint - 1) == .medium)
        #expect(WindowLayout.forWidth(WindowLayout.compactBreakpoint) == .medium)
        #expect(WindowLayout.forWidth(WindowLayout.compactBreakpoint - 1) == .compact)
        #expect(WindowLayout.forWidth(WindowLayout.minimumWindowWidth) == .compact)
    }

    @Test("Each layout shows the intended columns")
    func columns() {
        #expect(WindowLayout.wide.columnVisibility == .all)
        #expect(WindowLayout.medium.columnVisibility == .doubleColumn)
        #expect(WindowLayout.compact.columnVisibility == .detailOnly)
    }

    @Test("New cards carry the author from preferences")
    @MainActor
    func authorOnNewCards() {
        let store = CardStore(persistence: InMemoryCardPersistence())
        let card = store.add(template: .weeklyStatus, theme: .light, author: "Alex Chen")
        #expect(card.author == "Alex Chen")
        #expect(PlainTextRenderer().render(card).contains("· Alex Chen"))
    }
}
