import Foundation

/// Checks on what the author wrote, as opposed to how the card is styled.
///
/// These are heuristics. They are warnings, never errors: they point at
/// something a person should look at, and a person may disagree.
enum ContentChecks {
    /// Images with at least this many recognised words are treated as "mostly text".
    static let imageOfTextWordThreshold = 15
    /// Average words per sentence above which a block is flagged.
    static let longSentenceAverage = 28.0
    /// Cards with at least this many sections are expected to have headings.
    static let sectionsNeedingHeadings = 3

    static func lint(_ block: Block) -> [AccessibilityIssue] {
        switch block {
        case let .text(text):
            let strings = [text.heading, text.body]
            return colorLanguage(in: strings, blockID: text.id)
                + capitals(in: strings, blockID: text.id)
                + readability(of: text)
        case let .metrics(metrics):
            let strings = [metrics.heading] + metrics.metrics.map(\.label)
            return colorLanguage(in: strings, blockID: metrics.id) + capitals(in: strings, blockID: metrics.id)
        case let .image(image):
            return imageOfText(image) + colorLanguage(in: [image.caption], blockID: image.id)
        }
    }

    private static func warning(_ rule: AccessibilityRule, _ message: String, block: UUID) -> [AccessibilityIssue] {
        let issue = AccessibilityIssue(rule: rule, severity: .warning, message: message, blockID: block)
        return [issue]
    }

    // MARK: Section headings

    /// With several sections, headings are how a screen-reader user skims.
    static func lintHeadings(_ card: SnippetCard) -> [AccessibilityIssue] {
        var sections = 0
        var missing: [UUID] = []
        for block in card.blocks {
            switch block {
            case let .text(text) where !text.isEmpty:
                sections += 1
                if text.heading.trimmingCharacters(in: .whitespaces).isEmpty {
                    missing.append(text.id)
                }
            case let .metrics(metrics) where !metrics.isEmpty:
                sections += 1
                if metrics.heading.trimmingCharacters(in: .whitespaces).isEmpty {
                    missing.append(metrics.id)
                }
            default:
                continue
            }
        }
        guard sections >= sectionsNeedingHeadings, let first = missing.first else { return [] }
        let subject = missing.count == 1 ? "1 section has" : "\(missing.count) sections have"
        let message = "\(subject) no heading. Headings let screen-reader users jump between sections "
            + "instead of listening to everything."
        return warning(.sectionsHaveHeadings, message, block: first)
    }

    // MARK: Colour words

    private static let colorNames = "red|green|amber|yellow|orange|blue"
    private static let colorPattern = "(?i)"
        + #"\b(?:in|marked|shown|highlighted|flagged|coloured|colored)\s+(?:in\s+)?(?:"# + colorNames + #")\b"#
        + #"|\b(?:the\s+)?(?:"# + colorNames + #")\s+(?:items?|ones?|rows?|bars?|lines?|cells?|numbers?|figures?)\b"#

    static func colorLanguage(in strings: [String], blockID: UUID) -> [AccessibilityIssue] {
        guard let regex = try? NSRegularExpression(pattern: colorPattern) else { return [] }
        for text in strings {
            let range = NSRange(text.startIndex..., in: text)
            guard let match = regex.firstMatch(in: text, range: range), let found = Range(match.range, in: text) else { continue }
            let message = "“\(text[found])” points at something by colour. Say what it means as well, "
                + "for readers who cannot see or tell the colour."
            return warning(.meaningNotByColorAlone, message, block: blockID)
        }
        return []
    }

    // MARK: Capitals

    /// Four or more consecutive all-capital words. Short acronyms alone never trigger it.
    static func capitals(in strings: [String], blockID: UUID) -> [AccessibilityIssue] {
        for text in strings {
            var run: [Substring] = []
            for word in text.split(whereSeparator: { $0.isWhitespace }) {
                let letters = word.filter(\.isLetter)
                guard letters.count >= 2, letters.allSatisfy(\.isUppercase) else {
                    run.removeAll()
                    continue
                }
                run.append(word)
                if run.count >= 4 {
                    let message = "“\(run.joined(separator: " "))…” is written in capitals. Long runs of capitals are "
                        + "slower to read, and some screen readers spell them out letter by letter."
                    return warning(.noLongRunsOfCapitals, message, block: blockID)
                }
            }
        }
        return []
    }

    // MARK: Reading level

    static func averageSentenceLength(_ text: String) -> Double {
        let sentences = text
            .components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.split(whereSeparator: { $0.isWhitespace }).count }
            .filter { $0 > 0 }
        guard !sentences.isEmpty else { return 0 }
        return Double(sentences.reduce(0, +)) / Double(sentences.count)
    }

    static func readability(of block: TextBlock) -> [AccessibilityIssue] {
        let average = averageSentenceLength(block.body)
        guard average > longSentenceAverage else { return [] }
        let message = "Sentences here average \(Int(average.rounded())) words. Shorter sentences are easier for everyone, "
            + "including people using a screen reader, a magnifier or a translation."
        return warning(.sentencesAreReadable, message, block: block.id)
    }

    // MARK: Images of text

    static func imageOfText(_ image: ImageBlock) -> [AccessibilityIssue] {
        guard !image.isDecorative, let words = image.recognizedWordCount, words >= imageOfTextWordThreshold else { return [] }
        // A thorough description already carries the content.
        let describedWords = image.altText.split(whereSeparator: { $0.isWhitespace }).count
        guard describedWords * 2 < words else { return [] }
        let message = "This image contains about \(words) words. A screen reader cannot read text inside an image: "
            + "put the key facts in the description, a text block or metrics."
        return warning(.noImagesOfText, message, block: image.id)
    }
}
