import Foundation

/// The kind of content a block holds. Also used as the JSON discriminator.
public enum BlockKind: String, Codable, CaseIterable, Sendable {
    case text
    case metrics
    case image

    public var label: String {
        switch self {
        case .text: "Text"
        case .metrics: "Metrics"
        case .image: "Image"
        }
    }

    public var symbolName: String {
        switch self {
        case .text: "text.alignleft"
        case .metrics: "chart.bar.xaxis"
        case .image: "photo"
        }
    }
}

/// One modular section of a card.
public enum Block: Identifiable, Hashable, Sendable {
    case text(TextBlock)
    case metrics(MetricsBlock)
    case image(ImageBlock)

    public var id: UUID {
        switch self {
        case let .text(block): block.id
        case let .metrics(block): block.id
        case let .image(block): block.id
        }
    }

    public var kind: BlockKind {
        switch self {
        case .text: .text
        case .metrics: .metrics
        case .image: .image
        }
    }

    /// Heading shown for the block, if any.
    public var heading: String {
        switch self {
        case let .text(block): block.heading
        case let .metrics(block): block.heading
        case let .image(block): block.caption
        }
    }
}

extension Block: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(BlockKind.self, forKey: .kind)
        switch kind {
        case .text: self = try .text(TextBlock(from: decoder))
        case .metrics: self = try .metrics(MetricsBlock(from: decoder))
        case .image: self = try .image(ImageBlock(from: decoder))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        switch self {
        case let .text(block): try block.encode(to: encoder)
        case let .metrics(block): try block.encode(to: encoder)
        case let .image(block): try block.encode(to: encoder)
        }
    }
}
