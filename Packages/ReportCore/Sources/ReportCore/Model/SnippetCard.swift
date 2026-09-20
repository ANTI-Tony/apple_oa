import Foundation

/// The single source of truth for one "Snippet Card".
///
/// A card is a plain value type. Every consumer, the SwiftUI preview, the HTML
/// renderer used for email, the Markdown renderer used for chat tools and the
/// pasteboard writer, reads this same model. That guarantee is what makes
/// "what you see is what you paste" hold.
public struct SnippetCard: Identifiable, Hashable, Sendable {
    /// Bumped whenever the persisted JSON shape changes incompatibly.
    public static let currentSchemaVersion = 1

    public var id: UUID
    public var schemaVersion: Int
    /// Main heading of the card, e.g. "Weekly Status".
    public var title: String
    /// Context line rendered above the title, e.g. "Project Atlas · Week 38".
    public var subtitle: String
    /// Who is reporting. Shown in the footer when not empty. Part of the card,
    /// not a render option, so every export names the same author.
    public var author: String
    public var status: ReportStatus
    public var blocks: [Block]
    public var theme: CardTheme
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String = "",
        author: String = "",
        status: ReportStatus = .onTrack,
        blocks: [Block] = [],
        theme: CardTheme = .light,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        schemaVersion = Self.currentSchemaVersion
        self.title = title
        self.subtitle = subtitle
        self.author = author
        self.status = status
        self.blocks = blocks
        self.theme = theme
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Convenience

public extension SnippetCard {
    /// A card with no title and no blocks.
    static var blank: SnippetCard {
        SnippetCard(title: "")
    }

    var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && blocks.isEmpty
    }

    var imageBlocks: [ImageBlock] {
        blocks.compactMap { block in
            if case let .image(image) = block {
                return image
            }
            return nil
        }
    }

    func block(withID blockID: UUID) -> Block? {
        blocks.first { $0.id == blockID }
    }

    func index(ofBlock blockID: UUID) -> Int? {
        blocks.firstIndex { $0.id == blockID }
    }

    /// Records that the card changed. Callers that mutate `blocks` directly
    /// should call this so ordering by recency stays correct.
    mutating func touch(now: Date = Date()) {
        updatedAt = now
    }

    mutating func append(_ block: Block) {
        blocks.append(block)
        touch()
    }

    mutating func replace(_ block: Block) {
        guard let index = index(ofBlock: block.id) else { return }
        blocks[index] = block
        touch()
    }

    mutating func removeBlock(withID blockID: UUID) {
        blocks.removeAll { $0.id == blockID }
        touch()
    }

    /// Moves a block one position up or down. Exposed as explicit buttons in
    /// the editor so reordering never depends on drag and drop alone.
    mutating func moveBlock(withID blockID: UUID, by offset: Int) {
        guard let index = index(ofBlock: blockID) else { return }
        let destination = index + offset
        guard blocks.indices.contains(destination) else { return }
        blocks.swapAt(index, destination)
        touch()
    }

    /// Same contract as SwiftUI's `move(fromOffsets:toOffset:)`, implemented
    /// here so the core package has no SwiftUI dependency.
    mutating func moveBlocks(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.compactMap { blocks.indices.contains($0) ? blocks[$0] : nil }
        guard !moving.isEmpty else { return }
        let before = source.filter { $0 < destination }.count
        var remaining = blocks
        for index in source.sorted(by: >) where remaining.indices.contains(index) {
            remaining.remove(at: index)
        }
        let insertAt = max(0, min(destination - before, remaining.count))
        remaining.insert(contentsOf: moving, at: insertAt)
        blocks = remaining
        touch()
    }
}

// MARK: - Duplication

public extension Block {
    /// A copy with a fresh identifier, for duplicating cards.
    func withNewID() -> Block {
        switch self {
        case var .text(block):
            block.id = UUID()
            return .text(block)
        case var .metrics(block):
            block.id = UUID()
            block.metrics = block.metrics.map { metric in
                var copy = metric
                copy.id = UUID()
                return copy
            }
            return .metrics(block)
        case var .image(block):
            block.id = UUID()
            return .image(block)
        }
    }
}

public extension SnippetCard {
    /// An independent copy with new identifiers throughout.
    func duplicated(titleSuffix: String = " copy", now: Date = Date()) -> SnippetCard {
        var copy = self
        copy.id = UUID()
        copy.title = title.isEmpty ? "Untitled\(titleSuffix)" : title + titleSuffix
        copy.blocks = blocks.map { $0.withNewID() }
        copy.createdAt = now
        copy.updatedAt = now
        return copy
    }
}

// MARK: - Codable

extension SnippetCard: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, schemaVersion, title, subtitle, author, status, blocks, theme, createdAt, updatedAt
    }

    /// Lenient decoding: fields added in later schema versions fall back to
    /// defaults so older exports keep opening.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        author = try container.decodeIfPresent(String.self, forKey: .author) ?? ""
        status = try container.decodeIfPresent(ReportStatus.self, forKey: .status) ?? .onTrack
        blocks = try container.decodeIfPresent([Block].self, forKey: .blocks) ?? []
        theme = try container.decodeIfPresent(CardTheme.self, forKey: .theme) ?? .light
        let now = Date()
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? now
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(title, forKey: .title)
        try container.encode(subtitle, forKey: .subtitle)
        try container.encode(author, forKey: .author)
        try container.encode(status, forKey: .status)
        try container.encode(blocks, forKey: .blocks)
        try container.encode(theme, forKey: .theme)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}
