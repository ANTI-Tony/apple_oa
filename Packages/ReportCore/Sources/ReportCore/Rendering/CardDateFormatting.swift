import Foundation

/// Shared date formatting so every renderer prints the same footer.
public enum CardDateFormatting {
    public static func footerDate(_ date: Date, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /// "Updated 18 Sep 2026" or "Updated 18 Sep 2026 · Alex Chen". One source
    /// for every renderer, including the SwiftUI and rich-text ones in the app.
    public static func footerText(for card: SnippetCard, locale: Locale = .current) -> String {
        let date = footerDate(card.updatedAt, locale: locale)
        let author = card.author.trimmingCharacters(in: .whitespacesAndNewlines)
        return author.isEmpty ? "Updated \(date)" : "Updated \(date) · \(author)"
    }
}
