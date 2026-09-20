import Foundation

/// JSON encoding shared by persistence, import and export.
///
/// Dates are ISO 8601 with fractional seconds so a round trip is lossless;
/// keys are sorted so files diff cleanly in version control and exports are
/// byte-for-byte reproducible for the same card.
public enum CardCodec {
    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Self.fractionalFormatter.string(from: date))
        }
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            if let date = Self.fractionalFormatter.date(from: text) ?? Self.wholeSecondFormatter.date(from: text) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognised date \(text)")
        }
        return decoder
    }

    public static func encode(_ card: SnippetCard) throws -> Data {
        try encoder().encode(card)
    }

    public static func encode(_ cards: [SnippetCard]) throws -> Data {
        try encoder().encode(cards)
    }

    public static func decodeCard(_ data: Data) throws -> SnippetCard {
        try decoder().decode(SnippetCard.self, from: data)
    }

    /// Accepts either a single card object or an array of cards.
    public static func decodeCards(_ data: Data) throws -> [SnippetCard] {
        if let cards = try? decoder().decode([SnippetCard].self, from: data) {
            return cards
        }
        return try [decodeCard(data)]
    }

    // MARK: Date formats

    private static var fractionalFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    private static var wholeSecondFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }
}
