import AppKit
import Foundation
import PDFKit
import ReportCore
import Testing
@testable import ReportingBuilder

@MainActor
@Suite("Undo")
struct UndoTests {
    /// Groups are opened and closed by hand because there is no event loop in a
    /// test. `undo()` and `redo()` are called with no group open; they open
    /// their own, which is where the store records the inverse.
    private func makeUndoManager() -> UndoManager {
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        return undoManager
    }

    private func grouped(_ undoManager: UndoManager, _ body: () -> Void) {
        undoManager.beginUndoGrouping()
        body()
        undoManager.endUndoGrouping()
    }

    @Test("Structural edits are undoable and named; typing is left to the text field")
    func structuralUndo() {
        let store = CardStore(persistence: InMemoryCardPersistence(cards: [SampleContent.weeklyStatus()]))
        let undoManager = makeUndoManager()
        let original = store.cards[0]

        var reworded = original
        reworded.title = "Reworded"
        // No group is open here, so an attempt to register would raise: wording
        // alone must not reach the undo manager at all.
        store.update(reworded, undoManager: undoManager)
        #expect(!undoManager.canUndo)

        var moved = store.cards[0]
        moved.moveBlock(withID: moved.blocks[0].id, by: 1)
        grouped(undoManager) { store.update(moved, undoManager: undoManager) }
        #expect(undoManager.canUndo)
        #expect(undoManager.undoActionName == "Move Block")

        undoManager.undo()
        #expect(store.cards[0].blocks.map(\.id) == original.blocks.map(\.id))
        #expect(undoManager.canRedo)
        undoManager.redo()
        #expect(store.cards[0].blocks.map(\.id) == moved.blocks.map(\.id))
    }

    @Test("A rewrite by the assistant is one named undo step even though it is only wording")
    func namedWordingUndo() {
        let store = CardStore(persistence: InMemoryCardPersistence(cards: [SampleContent.weeklyStatus()]))
        let undoManager = makeUndoManager()
        var refined = store.cards[0]
        refined.title = "Refined title"
        grouped(undoManager) { store.update(refined, undoManager: undoManager, actionName: "Make Concise") }
        #expect(undoManager.undoActionName == "Make Concise")
        undoManager.undo()
        #expect(store.cards[0].title == "Weekly status")
    }

    @Test("Deleting a card can be undone, and it comes back where it was")
    func deleteUndo() {
        let cards = ["A", "B", "C"].map { SnippetCard(title: $0) }
        let store = CardStore(persistence: InMemoryCardPersistence(cards: cards))
        let undoManager = makeUndoManager()
        grouped(undoManager) { store.delete(id: cards[1].id, undoManager: undoManager) }
        #expect(store.cards.map(\.title) == ["A", "C"])
        undoManager.undo()
        #expect(store.cards.map(\.title) == ["A", "B", "C"])
        #expect(store.selectedCardID == cards[1].id)
    }
}

@MainActor
@Suite("Tagged PDF")
struct PDFTests {
    @Test("The PDF has real text, document metadata and a structure tree")
    func taggedPDF() throws {
        var card = SampleContent.weeklyStatus()
        card.author = "Alex Chen"
        let data = try #require(PDFCardComposer.data(for: card, width: 600))
        let document = try #require(PDFDocument(data: data))
        #expect(document.pageCount == 1)
        let text = try #require(document.string)
        #expect(text.contains("Weekly status"))
        #expect(text.contains("Velocity"))
        #expect(text.contains("Pilot rollout reached 3 of 5 regional teams"))
        #expect(document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String == "Weekly status")
        #expect(document.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String == "Alex Chen")
        #expect(abs((document.page(at: 0)?.bounds(for: .mediaBox).width ?? 0) - 600) < 1)

        let raw = String(decoding: data, as: Latin1.self)
        #expect(raw.contains("/StructTreeRoot"), "a tagged PDF declares its structure tree in the catalog")
        #expect(raw.contains("/MarkInfo"))
    }

    @Test("PDF is one of the export formats")
    func exportFormat() throws {
        let data = try CardExporter.data(for: SampleContent.weeklyStatus(), format: .pdf)
        #expect(data.prefix(5) == Data("%PDF-".utf8))
        #expect(CardExporter.suggestedFileName(for: SampleContent.weeklyStatus(), format: .pdf) == "Weekly-status.pdf")
    }

    @Test("Large print makes a taller PDF from the same card")
    func largePrint() throws {
        var card = SampleContent.weeklyStatus()
        let standardData = try #require(PDFCardComposer.data(for: card))
        let standard = try #require(PDFDocument(data: standardData))
        card.textSize = .extraLarge
        let largeData = try #require(PDFCardComposer.data(for: card))
        let large = try #require(PDFDocument(data: largeData))
        let standardHeight = standard.page(at: 0)?.bounds(for: .mediaBox).height ?? 0
        let largeHeight = large.page(at: 0)?.bounds(for: .mediaBox).height ?? 0
        #expect(largeHeight > standardHeight * 1.1)
    }
}

/// ISO 8859-1 maps every byte to a character, which makes it safe for searching raw PDF bytes.
private enum Latin1: Unicode.Encoding {
    typealias CodeUnit = UInt8
    typealias EncodedScalar = CollectionOfOne<UInt8>
    typealias ForwardParser = Parser
    typealias ReverseParser = Parser

    static var encodedReplacementCharacter: EncodedScalar {
        CollectionOfOne(0x3F)
    }

    static func decode(_ content: EncodedScalar) -> Unicode.Scalar {
        Unicode.Scalar(content[content.startIndex])
    }

    static func encode(_ content: Unicode.Scalar) -> EncodedScalar? {
        content.value < 256 ? CollectionOfOne(UInt8(content.value)) : nil
    }

    struct Parser: Unicode.Parser {
        typealias Encoding = Latin1

        init() {}

        mutating func parseScalar<I: IteratorProtocol>(from input: inout I) -> Unicode.ParseResult<EncodedScalar> where I.Element == UInt8 {
            guard let byte = input.next() else { return .emptyInput }
            return .valid(CollectionOfOne(byte))
        }
    }
}

@MainActor
@Suite("Colour vision and audio graph")
struct VisionAndGraphTests {
    @Test("Each simulation keeps white white and grey grey")
    func neutralsSurvive() {
        for simulation in VisionSimulation.allCases {
            let white = simulation.apply(red: 1, green: 1, blue: 1)
            #expect(abs(white.red - 1) < 0.01 && abs(white.green - 1) < 0.01 && abs(white.blue - 1) < 0.01, "\(simulation)")
            let grey = simulation.apply(red: 0.5, green: 0.5, blue: 0.5)
            #expect(abs(grey.red - 0.5) < 0.01 && abs(grey.green - 0.5) < 0.01, "\(simulation)")
        }
    }

    @Test("Red and green collapse towards each other for red-green deficiencies")
    func redGreenConfusion() {
        let red = VisionSimulation.deuteranopia.apply(red: 1, green: 0, blue: 0)
        let green = VisionSimulation.deuteranopia.apply(red: 0, green: 1, blue: 0)
        #expect(abs(red.red - green.red) < 0.3)
        #expect(abs(red.green - green.green) < 0.45)
        let grey = VisionSimulation.achromatopsia.apply(red: 1, green: 0, blue: 0)
        #expect(grey.red == grey.green && grey.green == grey.blue)
        let unchanged = VisionSimulation.none.apply(red: 0.2, green: 0.4, blue: 0.6)
        #expect(unchanged.red == 0.2 && unchanged.green == 0.4 && unchanged.blue == 0.6)
    }

    @Test("The simulator filters a rendered card without changing its size")
    func simulateImage() throws {
        let image = try #require(CardExporter.cgImage(for: SampleContent.weeklyStatus(), width: 600, scale: 1))
        let simulated = try #require(VisionSimulator.simulate(image, as: .protanopia))
        #expect(simulated.width == image.width)
        #expect(simulated.height == image.height)
    }

    @Test("Trend summaries say which way the line went")
    func trendSummary() {
        #expect(TrendChartDescriptor.summary(of: [36, 38, 42]) == "Over 3 periods the value rose from 36 to 42.")
        #expect(TrendChartDescriptor.summary(of: [21, 12]) == "Over 2 periods the value fell from 21 to 12.")
        #expect(TrendChartDescriptor.summary(of: [5, 5]) == "Over 2 periods the value stayed level from 5 to 5.")
        #expect(TrendChartDescriptor.summary(of: [5]) == "No trend data.")
        let descriptor = TrendChartDescriptor(metric: Metric(label: "Velocity", value: "42", trend: [36, 38, 42])).makeChartDescriptor()
        #expect(descriptor.series.first?.dataPoints.count == 3)
        #expect(descriptor.title == "Velocity trend")
    }

    @Test("Speaking nothing leaves the player idle")
    func speechIdle() {
        let player = SpeechPlayer()
        player.speak([])
        #expect(!player.isSpeaking)
        player.stop()
        #expect(player.currentSegment == nil)
    }
}
