import SwiftUI
import Testing
@testable import ReportingBuilder

@Suite("Help guide and the shortcut catalogue")
struct HelpGuideTests {
    @Test("Every catalogued command carries a title, glyphs and a spoken form")
    func everyEntryIsComplete() {
        for shortcut in MenuShortcut.allCases {
            #expect(!shortcut.title.isEmpty, "\(shortcut.rawValue) has no title")
            #expect(!shortcut.glyphs.isEmpty, "\(shortcut.rawValue) renders no glyphs")
            #expect(!shortcut.spoken.isEmpty, "\(shortcut.rawValue) has nothing for VoiceOver")
            // Every binding in this app uses Command; a bare letter would steal typing.
            #expect(shortcut.modifiers.contains(.command), "\(shortcut.rawValue) is not a Command shortcut")
        }
    }

    @Test("No two commands claim the same key equivalent")
    func noCollisions() {
        var seen: [String: String] = [:]
        for shortcut in MenuShortcut.allCases {
            let binding = "\(shortcut.key.character)-\(shortcut.modifiers.rawValue)"
            #expect(seen[binding] == nil, "\(shortcut.rawValue) collides with \(seen[binding] ?? "")")
            seen[binding] = shortcut.rawValue
        }
    }

    @Test("Glyphs follow the menu bar's modifier order and name the special keys")
    func glyphsAreReadable() {
        #expect(MenuShortcut.newCard.glyphs == "⌘N")
        #expect(MenuShortcut.copyForEmail.glyphs == "⇧⌘C")
        #expect(MenuShortcut.copyAsImage.glyphs == "⌥⌘C")
        // The pair a user must be able to tell apart.
        #expect(MenuShortcut.deleteCard.glyphs == "⌘⌫")
        #expect(MenuShortcut.deleteBlock.glyphs == "⌥⌘⌫")
        #expect(MenuShortcut.moveBlockUp.glyphs == "⌥⌘↑")
        #expect(MenuShortcut.moveBlockDown.glyphs == "⌥⌘↓")
    }

    @Test("VoiceOver hears words where the eye sees glyphs")
    func spokenFormsAreWords() {
        #expect(MenuShortcut.deleteCard.spoken == "Command Delete")
        #expect(MenuShortcut.deleteBlock.spoken == "Option Command Delete")
        #expect(MenuShortcut.moveBlockUp.spoken == "Option Command Up Arrow")
        #expect(MenuShortcut.copyForEmail.spoken == "Shift Command C")
        for shortcut in MenuShortcut.allCases {
            #expect(!shortcut.spoken.contains("⌘"), "\(shortcut.rawValue) leaks a glyph into speech")
        }
    }

    @Test("Each command is filed under a menu that exists, and every menu has commands")
    func menusAreCovered() {
        for menu in MenuShortcut.Menu.allCases {
            let commands = MenuShortcut.allCases.filter { $0.menu == menu }
            #expect(!commands.isEmpty, "the \(menu.label) menu section would render empty")
            #expect(!menu.label.isEmpty)
        }
    }

    @Test("The help window offers a page for every topic, each with a title and a symbol")
    func topicsAreComplete() {
        #expect(HelpTopic.allCases.count == 4)
        for topic in HelpTopic.allCases {
            #expect(!topic.title.isEmpty)
            #expect(!topic.symbolName.isEmpty)
        }
    }

    @MainActor
    @Test("Help opens on the shortcut list and remembers the topic the menu asked for")
    func helpStateTracksTheChosenTopic() {
        let help = HelpState()
        #expect(help.topic == .shortcuts)
        help.topic = .storage
        #expect(help.topic == .storage)
    }
}
