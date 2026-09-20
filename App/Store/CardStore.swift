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
            var seed = SampleContent.cards()
            if LaunchOverrides.demoState == "largePrint", !seed.isEmpty {
                seed[0].textSize = .extraLarge
            }
            if LaunchOverrides.seedsMissingDescription, !seed.isEmpty {
                // An image nobody described, for the accessibility demo and its UI test.
                seed[0].blocks = seed[0].blocks.map { block in
                    guard case var .image(image) = block else { return block }
                    image.altText = ""
                    return .image(image)
                }
            }
            return CardStore(persistence: InMemoryCardPersistence(), seed: seed)
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

    /// Replaces a card. Structural edits (add, move, delete, restyle) are
    /// recorded for Undo; wording is not, because the text field being typed in
    /// already undoes typing. Pass `actionName` to record a wording change
    /// that did not come from typing, such as a rewrite by the assistant.
    func update(_ card: SnippetCard, undoManager: UndoManager? = nil, actionName: String? = nil) {
        guard let index = cards.firstIndex(where: { $0.id == card.id }), cards[index] != card else { return }
        let previous = cards[index]
        var updated = card
        updated.touch()
        cards[index] = updated
        scheduleSave()
        if let undoManager, let name = actionName ?? card.structuralChangeName(since: previous) {
            registerUndo(restoring: previous, with: undoManager, actionName: name)
        }
    }

    private func registerUndo(restoring snapshot: SnippetCard, with undoManager: UndoManager, actionName: String) {
        undoManager.registerUndo(withTarget: self) { store in
            MainActor.assumeIsolated {
                store.restore(snapshot, with: undoManager, actionName: actionName)
            }
        }
        undoManager.setActionName(actionName)
    }

    /// Puts a snapshot back and records the inverse, which is what makes Redo work.
    private func restore(_ snapshot: SnippetCard, with undoManager: UndoManager, actionName: String) {
        guard let index = cards.firstIndex(where: { $0.id == snapshot.id }) else { return }
        let current = cards[index]
        cards[index] = snapshot
        scheduleSave()
        registerUndo(restoring: current, with: undoManager, actionName: actionName)
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

    func delete(id: UUID, undoManager: UndoManager? = nil) {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
        let removed = cards[index]
        if let undoManager {
            undoManager.registerUndo(withTarget: self) { store in
                MainActor.assumeIsolated {
                    store.reinsert(removed, at: index, with: undoManager)
                }
            }
            undoManager.setActionName("Delete Card")
        }
        cards.remove(at: index)
        if selectedCardID == id {
            selectedCardID = cards.indices.contains(index) ? cards[index].id : cards.last?.id
        }
        scheduleSave()
    }

    private func reinsert(_ card: SnippetCard, at index: Int, with undoManager: UndoManager) {
        cards.insert(card, at: min(index, cards.count))
        selectedCardID = card.id
        scheduleSave()
        undoManager.registerUndo(withTarget: self) { store in
            MainActor.assumeIsolated {
                store.delete(id: card.id, undoManager: undoManager)
            }
        }
        undoManager.setActionName("Delete Card")
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
