import Foundation
import Observation
import OSLog
import ReportCore

/// The list of cards and the current selection.
///
/// Mutations go through this object so persistence (debounced, atomic) and
/// selection bookkeeping stay in one place. Views bind to cards through
/// `update(_:)`, which only writes when something actually changed.
@MainActor
@Observable
final class CardStore {
    static let shared = CardStore.makeDefault()

    private(set) var cards: [SnippetCard] = []
    var selectedCardID: UUID?
    private(set) var lastSaveError: String?

    private let persistence: any CardPersistence
    private var saveTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.tonywen.reportingbuilder", category: "store")

    init(persistence: any CardPersistence, seed: [SnippetCard] = []) {
        self.persistence = persistence
        do {
            cards = try persistence.load()
        } catch {
            logger.error("Could not load cards: \(error.localizedDescription, privacy: .public)")
            cards = []
        }
        if cards.isEmpty, !seed.isEmpty {
            cards = seed
            scheduleSave()
        }
        selectedCardID = cards.first?.id
    }

    /// Chooses persistence from launch arguments and feature flags.
    static func makeDefault() -> CardStore {
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            return CardStore(persistence: InMemoryCardPersistence(), seed: SampleContent.cards())
        }
        let seed = AppConfiguration.isEnabled(.sampleContent) ? SampleContent.cards() : []
        return CardStore(persistence: FileCardPersistence(url: AppPaths.cardsFile), seed: seed)
    }

    // MARK: Reading

    var selectedCard: SnippetCard? {
        cards.first { $0.id == selectedCardID }
    }

    func card(withID id: UUID) -> SnippetCard? {
        cards.first { $0.id == id }
    }

    // MARK: Writing

    @discardableResult
    func add(_ card: SnippetCard, select: Bool = true) -> SnippetCard {
        cards.insert(card, at: 0)
        if select {
            selectedCardID = card.id
        }
        scheduleSave()
        return card
    }

    @discardableResult
    func add(template: CardTemplate, theme: CardTheme? = nil, author: String = "") -> SnippetCard {
        var card = template.makeCard()
        if let theme {
            card.theme = theme
        }
        card.author = author
        return add(card)
    }

    func update(_ card: SnippetCard) {
        guard let index = cards.firstIndex(where: { $0.id == card.id }), cards[index] != card else { return }
        var updated = card
        updated.touch()
        cards[index] = updated
        scheduleSave()
    }

    @discardableResult
    func duplicate(id: UUID) -> SnippetCard? {
        guard let original = card(withID: id) else { return nil }
        let copy = original.duplicated()
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return nil }
        cards.insert(copy, at: index + 1)
        selectedCardID = copy.id
        scheduleSave()
        return copy
    }

    func delete(id: UUID) {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
        cards.remove(at: index)
        if selectedCardID == id {
            selectedCardID = cards.indices.contains(index) ? cards[index].id : cards.last?.id
        }
        scheduleSave()
    }

    /// Imports cards from JSON produced by this app. Imported cards get fresh
    /// identifiers so importing the same file twice never collides.
    @discardableResult
    func importCards(from data: Data) throws -> Int {
        let imported = try CardCodec.decodeCards(data).map { $0.duplicated(titleSuffix: "") }
        guard !imported.isEmpty else { return 0 }
        cards.insert(contentsOf: imported, at: 0)
        selectedCardID = imported.first?.id
        scheduleSave()
        return imported.count
    }

    // MARK: Persistence

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self else { return }
            saveNow()
        }
    }

    func saveNow() {
        do {
            try persistence.save(cards)
            lastSaveError = nil
        } catch {
            lastSaveError = error.localizedDescription
            logger.error("Could not save cards: \(error.localizedDescription, privacy: .public)")
        }
    }
}
