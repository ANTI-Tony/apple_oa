import SwiftUI

/// Every key equivalent the menu bar binds, in one place.
///
/// `CardCommands` takes its shortcuts from here and the help window renders its
/// list from the same values, so the guide cannot print a shortcut the app does
/// not bind. `glyphs` is computed from `key` and `modifiers` rather than stored,
/// so the printed form cannot disagree with the binding either.
///
/// Commands without a key equivalent are deliberately absent: this catalogue
/// covers what is bound, not every menu item.
enum MenuShortcut: String, CaseIterable, Identifiable {
    case newCard, newCardFromNotes, importCards, printCard
    case pasteAsBlock
    case insertText, insertMetrics, insertImage
    case copyForEmail, copyAsImage
    case moveBlockUp, moveBlockDown, deleteBlock
    case checkAccessibility, hearThisCard, duplicateCard, deleteCard
    case formatInspector

    /// The menu the command lives in, used to group the guide.
    enum Menu: String, CaseIterable, Identifiable {
        case file, edit, insert, card, view

        var id: String {
            rawValue
        }

        var label: String {
            switch self {
            case .file: "File"
            case .edit: "Edit"
            case .insert: "Insert"
            case .card: "Card"
            case .view: "View"
            }
        }
    }

    var id: String {
        rawValue
    }

    var menu: Menu {
        switch self {
        case .newCard, .newCardFromNotes, .importCards, .printCard: .file
        case .pasteAsBlock: .edit
        case .insertText, .insertMetrics, .insertImage: .insert
        case .formatInspector: .view
        default: .card
        }
    }

    /// The exact menu title, so the guide and the menu bar say the same words.
    var title: String {
        switch self {
        case .newCard: "New Card"
        case .newCardFromNotes: "New Card from Notes…"
        case .importCards: "Import Cards…"
        case .printCard: "Print…"
        case .pasteAsBlock: "Paste as Block"
        case .insertText: "Text"
        case .insertMetrics: "Metrics"
        case .insertImage: "Image…"
        case .copyForEmail: "Copy for Email"
        case .copyAsImage: "Copy as Image"
        case .moveBlockUp: "Move Block Up"
        case .moveBlockDown: "Move Block Down"
        case .deleteBlock: "Delete Block"
        case .checkAccessibility: "Check Accessibility"
        case .hearThisCard: "Hear This Card"
        case .duplicateCard: "Duplicate Card"
        case .deleteCard: "Delete Card"
        case .formatInspector: "Format Inspector"
        }
    }

    var key: KeyEquivalent {
        switch self {
        case .newCard, .newCardFromNotes: "n"
        case .importCards: "o"
        case .printCard: "p"
        case .pasteAsBlock: "v"
        case .insertText: "t"
        case .insertMetrics: "m"
        case .insertImage: "g"
        case .copyForEmail, .copyAsImage: "c"
        case .moveBlockUp: .upArrow
        case .moveBlockDown: .downArrow
        case .deleteBlock, .deleteCard: .delete
        case .checkAccessibility: "k"
        case .hearThisCard: "l"
        case .duplicateCard: "d"
        case .formatInspector: "i"
        }
    }

    var modifiers: EventModifiers {
        switch self {
        case .newCard, .importCards, .printCard, .duplicateCard, .deleteCard: .command
        case .newCardFromNotes, .pasteAsBlock, .copyForEmail, .checkAccessibility: [.command, .shift]
        default: [.command, .option]
        }
    }

    /// Spelled out for VoiceOver, which reads a run of modifier glyphs as
    /// punctuation or as nothing at all. ⌘⌫ and ⌥⌘⌫ are the pair that matters.
    var spoken: String {
        var words: [String] = []
        if modifiers.contains(.control) {
            words.append("Control")
        }
        if modifiers.contains(.option) {
            words.append("Option")
        }
        if modifiers.contains(.shift) {
            words.append("Shift")
        }
        if modifiers.contains(.command) {
            words.append("Command")
        }
        words.append(Self.spokenKey(key))
        return words.joined(separator: " ")
    }

    /// Modifier order follows the menu bar's own: ⌃⌥⇧⌘.
    var glyphs: String {
        var symbols = ""
        if modifiers.contains(.control) {
            symbols += "⌃"
        }
        if modifiers.contains(.option) {
            symbols += "⌥"
        }
        if modifiers.contains(.shift) {
            symbols += "⇧"
        }
        if modifiers.contains(.command) {
            symbols += "⌘"
        }
        return symbols + Self.glyph(key)
    }

    static func glyph(_ key: KeyEquivalent) -> String {
        switch key.character {
        case KeyEquivalent.delete.character: "⌫"
        case KeyEquivalent.upArrow.character: "↑"
        case KeyEquivalent.downArrow.character: "↓"
        default: String(key.character).uppercased()
        }
    }

    static func spokenKey(_ key: KeyEquivalent) -> String {
        switch key.character {
        case KeyEquivalent.delete.character: "Delete"
        case KeyEquivalent.upArrow.character: "Up Arrow"
        case KeyEquivalent.downArrow.character: "Down Arrow"
        default: String(key.character).uppercased()
        }
    }
}

extension View {
    /// Binds a key equivalent from the one catalogue the help window renders,
    /// so the guide and the menu bar cannot disagree about a shortcut.
    func keyboardShortcut(_ shortcut: MenuShortcut) -> some View {
        keyboardShortcut(shortcut.key, modifiers: shortcut.modifiers)
    }
}
