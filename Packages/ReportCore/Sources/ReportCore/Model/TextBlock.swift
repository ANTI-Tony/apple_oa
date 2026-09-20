import Foundation

/// Free text with an optional heading.
///
/// The body uses a deliberately tiny markup subset: lines that start with
/// `- `, `* ` or `• ` become list items, blank lines separate paragraphs.
/// Everything else is literal text. Keeping the subset small means the
/// HTML, Markdown, plain-text and SwiftUI renderers all agree on the result.
public struct TextBlock: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var heading: String
    public var body: String

    public init(id: UUID = UUID(), heading: String = "", body: String = "") {
        self.id = id
        self.heading = heading
        self.body = body
    }

    public var isEmpty: Bool {
        heading.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The body parsed into paragraphs and bullet lists.
    public var fragments: [TextFragment] {
        TextFragment.parse(body)
    }
}

/// A paragraph or a bullet list produced from a `TextBlock` body.
public enum TextFragment: Hashable, Sendable {
    case paragraph(String)
    case bullets([String])

    private static let bulletPrefixes = ["- ", "* ", "• "]

    static func bulletContent(of line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        for prefix in bulletPrefixes where trimmed.hasPrefix(prefix) {
            return String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    public static func parse(_ body: String) -> [TextFragment] {
        var fragments: [TextFragment] = []
        var paragraph: [String] = []
        var bullets: [String] = []

        func flushParagraph() {
            if !paragraph.isEmpty {
                fragments.append(.paragraph(paragraph.joined(separator: " ")))
                paragraph.removeAll()
            }
        }
        func flushBullets() {
            if !bullets.isEmpty {
                fragments.append(.bullets(bullets))
                bullets.removeAll()
            }
        }

        for rawLine in body.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flushParagraph()
                flushBullets()
            } else if let item = bulletContent(of: line) {
                flushParagraph()
                bullets.append(item)
            } else {
                flushBullets()
                paragraph.append(line)
            }
        }
        flushParagraph()
        flushBullets()
        return fragments
    }
}
