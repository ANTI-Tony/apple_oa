import Foundation
import ReportCore
import Testing
@testable import ReportingBuilder

@MainActor
@Suite("CardStore")
struct CardStoreTests {
    @Test("Seeds sample cards only when nothing is persisted")
    func seeding() {
        let fresh = CardStore(persistence: InMemoryCardPersistence(), seed: SampleContent.cards())
        #expect(fresh.cards.count == 3)
        #expect(fresh.selectedCardID == fresh.cards.first?.id)

        let existing = CardStore(
            persistence: InMemoryCardPersistence(cards: [SnippetCard(title: "Existing")]),
            seed: SampleContent.cards()
        )
        #expect(existing.cards.map(\.title) == ["Existing"])
    }

    @Test("Adding selects the new card and persists after the debounce")
    func addPersists() async throws {
        let persistence = InMemoryCardPersistence()
        let store = CardStore(persistence: persistence)
        let card = store.add(template: .weeklyStatus, theme: .dark)
        #expect(store.selectedCardID == card.id)
        #expect(store.cards.first?.theme == .dark)
        try await Task.sleep(for: .milliseconds(800))
        #expect(persistence.saveCount == 1)
        #expect(persistence.cards.first?.id == card.id)
    }

    @Test("Update writes only real changes and bumps updatedAt")
    func update() {
        let store = CardStore(persistence: InMemoryCardPersistence(cards: [SnippetCard(title: "A")]))
        var card = store.cards[0]
        let before = card.updatedAt
        store.update(card)
        #expect(store.cards[0].updatedAt == before, "no-op update leaves the card untouched")
        card.title = "B"
        store.update(card)
        #expect(store.cards[0].title == "B")
        #expect(store.cards[0].updatedAt >= before)
    }

    @Test("Delete moves the selection to a neighbour")
    func delete() {
        let cards = ["A", "B", "C"].map { SnippetCard(title: $0) }
        let store = CardStore(persistence: InMemoryCardPersistence(cards: cards))
        store.selectedCardID = cards[1].id
        store.delete(id: cards[1].id)
        #expect(store.cards.map(\.title) == ["A", "C"])
        #expect(store.selectedCardID == cards[2].id)
        store.delete(id: cards[2].id)
        #expect(store.selectedCardID == cards[0].id)
    }

    @Test("Duplicate inserts an independent copy after the original")
    func duplicate() {
        let store = CardStore(persistence: InMemoryCardPersistence(), seed: SampleContent.cards())
        let original = store.cards[0]
        let copy = store.duplicate(id: original.id)
        #expect(copy?.id != original.id)
        #expect(store.cards[1].id == copy?.id)
        #expect(store.selectedCardID == copy?.id)
        #expect(copy?.blocks.count == original.blocks.count)
    }

    @Test("Import accepts the app's own JSON and assigns fresh identifiers")
    func importJSON() throws {
        let exported = try CardCodec.encode(SampleContent.cards())
        let store = CardStore(persistence: InMemoryCardPersistence())
        let count = try store.importCards(from: exported)
        #expect(count == 3)
        let again = try store.importCards(from: exported)
        #expect(again == 3)
        #expect(Set(store.cards.map(\.id)).count == 6)
    }

    @Test("File persistence round-trips through disk (dates keep millisecond precision)")
    func filePersistence() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "rb-tests-\(UUID().uuidString)")
        let persistence = FileCardPersistence(url: directory.appending(path: "cards.json"))
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(try persistence.load().isEmpty)
        let cards = SampleContent.cards()
        try persistence.save(cards)
        let loaded = try persistence.load()
        #expect(loaded.count == cards.count)
        for (original, restored) in zip(cards, loaded) {
            #expect(restored.id == original.id)
            #expect(restored.title == original.title)
            #expect(restored.status == original.status)
            #expect(restored.theme == original.theme)
            #expect(restored.blocks == original.blocks)
            #expect(abs(restored.createdAt.timeIntervalSince(original.createdAt)) < 0.001)
            #expect(abs(restored.updatedAt.timeIntervalSince(original.updatedAt)) < 0.001)
        }
    }
}
