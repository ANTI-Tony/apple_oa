import Foundation
import ReportCore

/// Where cards live between launches. The store talks to this protocol only,
/// so tests use an in-memory implementation and the app uses a JSON file.
@MainActor
protocol CardPersistence {
    func load() throws -> [SnippetCard]
    func save(_ cards: [SnippetCard]) throws
}

@MainActor
final class InMemoryCardPersistence: CardPersistence {
    private(set) var cards: [SnippetCard]
    private(set) var saveCount = 0

    init(cards: [SnippetCard] = []) {
        self.cards = cards
    }

    func load() throws -> [SnippetCard] {
        cards
    }

    func save(_ cards: [SnippetCard]) throws {
        self.cards = cards
        saveCount += 1
    }
}

/// Persists cards as one pretty-printed JSON file (see `CardCodec`).
struct FileCardPersistence: CardPersistence {
    let url: URL

    func load() throws -> [SnippetCard] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try CardCodec.decodeCards(Data(contentsOf: url))
    }

    func save(_ cards: [SnippetCard]) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try CardCodec.encode(cards).write(to: url, options: .atomic)
    }
}

enum AppPaths {
    /// `~/Library/Application Support/ReportingBuilder/cards.json`, inside the
    /// sandbox container when the app is sandboxed.
    static var cardsFile: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appending(path: "ReportingBuilder", directoryHint: .isDirectory)
            .appending(path: "cards.json")
    }
}
