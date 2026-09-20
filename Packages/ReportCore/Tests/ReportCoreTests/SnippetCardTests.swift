import Foundation
import Testing
@testable import ReportCore

@Suite("SnippetCard model")
struct SnippetCardTests {
    @Test("JSON round trip preserves every field")
    func roundTrip() throws {
        let card = Fixtures.card()
        let data = try CardCodec.encode(card)
        let decoded = try CardCodec.decodeCard(data)
        #expect(decoded == card)
    }

    @Test("Blocks serialise with a kind discriminator, not Swift enum payload keys")
    func blockDiscriminator() throws {
        let data = try CardCodec.encode(Fixtures.card())
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"kind\" : \"text\""))
        #expect(json.contains("\"kind\" : \"metrics\""))
        #expect(json.contains("\"kind\" : \"image\""))
        #expect(!json.contains("\"_0\""))
    }

    @Test("Decoding tolerates missing optional fields from older exports")
    func lenientDecoding() throws {
        let json = #"{"title": "Old card", "blocks": [{"kind": "text", "id": "\#(UUID().uuidString)", "heading": "", "body": "hi"}]}"#
        let card = try CardCodec.decodeCard(Data(json.utf8))
        #expect(card.title == "Old card")
        #expect(card.status == .onTrack)
        #expect(card.theme == .light)
        #expect(card.blocks.count == 1)
    }

    @Test("decodeCards accepts a single object or an array")
    func decodeEither() throws {
        let single = try CardCodec.encode(Fixtures.card())
        let many = try CardCodec.encode([Fixtures.card(), Fixtures.card()])
        #expect(try CardCodec.decodeCards(single).count == 1)
        #expect(try CardCodec.decodeCards(many).count == 2)
    }

    @Test("moveBlock by offset swaps neighbours and ignores out-of-range moves")
    func moveByOffset() {
        var card = Fixtures.card()
        let first = card.blocks[0].id
        card.moveBlock(withID: first, by: 1)
        #expect(card.blocks[1].id == first)
        card.moveBlock(withID: first, by: -1)
        #expect(card.blocks[0].id == first)
        card.moveBlock(withID: first, by: -1)
        #expect(card.blocks[0].id == first)
    }

    @Test("moveBlocks matches SwiftUI move semantics")
    func moveByOffsets() {
        var card = Fixtures.card()
        let ids = card.blocks.map(\.id)
        card.moveBlocks(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        #expect(card.blocks.map(\.id) == [ids[1], ids[2], ids[0]])
        card.moveBlocks(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        #expect(card.blocks.map(\.id) == ids)
    }

    @Test("Text bodies parse into paragraphs and bullet lists")
    func textFragments() {
        let block = TextBlock(body: "Intro line\nstill intro\n\n- one\n* two\n• three\n\nOutro")
        #expect(block.fragments == [
            .paragraph("Intro line\nstill intro"),
            .bullets(["one", "two", "three"]),
            .paragraph("Outro"),
        ])
    }

    @Test("Image content type is sniffed from magic bytes")
    func imageSniffing() {
        #expect(ImageContentType.detect(from: Fixtures.onePixelPNG) == .png)
        #expect(ImageContentType.detect(from: Data([0xFF, 0xD8, 0xFF, 0xE0])) == .jpeg)
        #expect(ImageContentType.detect(from: Data("hello".utf8)) == nil)
    }

    @Test("Every built-in template produces a distinct, non-empty card")
    func templates() {
        for template in CardTemplate.builtIn {
            let card = template.makeCard()
            #expect(!card.title.isEmpty, "\(template.id) has a title")
            #expect(template.makeCard().id != card.id, "\(template.id) makes fresh ids")
        }
        #expect(Set(CardTemplate.builtIn.map(\.id)).count == CardTemplate.builtIn.count)
    }
}

@Suite("Codec and naming")
struct CodecTests {
    @Test("Dates survive a round trip with sub-second precision")
    func fractionalDates() throws {
        var card = Fixtures.card()
        card.updatedAt = Date(timeIntervalSince1970: 1_700_000_000.123_456)
        let decoded = try CardCodec.decodeCard(CardCodec.encode(card))
        #expect(abs(decoded.updatedAt.timeIntervalSince(card.updatedAt)) < 0.001)
    }

    @Test("Whole-second ISO 8601 dates from other tools still decode")
    func wholeSecondDates() throws {
        let json = #"{"title": "Old", "createdAt": "2026-01-02T03:04:05Z", "updatedAt": "2026-01-02T03:04:05Z"}"#
        let card = try CardCodec.decodeCard(Data(json.utf8))
        #expect(card.createdAt == Date(timeIntervalSince1970: 1_767_323_045))
    }

    @Test("File-safe names collapse punctuation and whitespace")
    func fileNames() {
        #expect("Q3 / plan: \"final\"?".fileNameSafe == "Q3-plan-final")
        #expect("  Weekly   status  ".fileNameSafe == "Weekly-status")
        #expect("".fileNameSafe == "card")
        #expect("///".fileNameSafe == "card")
        #expect(String(repeating: "a", count: 80).fileNameSafe.count == 60)
    }
}
