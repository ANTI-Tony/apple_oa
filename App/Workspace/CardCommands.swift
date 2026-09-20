import ReportCore
import SwiftUI
import UniformTypeIdentifiers

/// Menu bar commands. Every toolbar action has a menu item and a shortcut so
/// the whole app is operable from the keyboard, including block reordering.
struct CardCommands: Commands {
    let store: CardStore
    let workspace: WorkspaceState
    let preferences: UserPreferences

    @FocusedValue(\.activeBlockID) private var activeBlockID: UUID?

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Card") {
                store.add(template: preferences.defaultTemplate, theme: preferences.defaultTheme, author: preferences.authorName)
            }
            .keyboardShortcut("n", modifiers: .command)

            Menu("New Card from Template") {
                ForEach(CardTemplate.builtIn) { template in
                    Button(template.name) {
                        store.add(template: template, theme: preferences.defaultTheme, author: preferences.authorName)
                    }
                }
            }

            Divider()

            Button("Import Cards…") { importCards() }
                .keyboardShortcut("o", modifiers: .command)
        }

        CommandMenu("Card") {
            Group {
                Button("Copy for Email") { copy(.rich) }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                Button("Copy as Image") { copy(.image) }
                    .keyboardShortcut("c", modifiers: [.command, .option])
                Button("Copy as Markdown") { copy(.markdown) }
                Button("Copy for Slack") { copy(.slack) }
                Button("Copy as Plain Text") { copy(.plain) }
                Button("Copy HTML Source") { copy(.html) }

                Divider()

                ForEach(ExportFormat.allCases) { format in
                    Button("Export as \(format.label)…") { export(format) }
                }

                Divider()

                Button("Move Block Up") { moveActiveBlock(by: -1) }
                    .keyboardShortcut(.upArrow, modifiers: [.command, .option])
                    .disabled(activeBlockID == nil)
                Button("Move Block Down") { moveActiveBlock(by: 1) }
                    .keyboardShortcut(.downArrow, modifiers: [.command, .option])
                    .disabled(activeBlockID == nil)
                Button("Delete Block") { deleteActiveBlock() }
                    .keyboardShortcut(.delete, modifiers: [.command, .option])
                    .disabled(activeBlockID == nil)

                Divider()

                Button("Duplicate Card") {
                    if let id = store.selectedCardID {
                        store.duplicate(id: id)
                    }
                }
                .keyboardShortcut("d", modifiers: .command)

                Button("Delete Card") {
                    if let id = store.selectedCardID {
                        store.delete(id: id)
                    }
                }
                .keyboardShortcut(.delete, modifiers: .command)
            }
            .disabled(store.selectedCard == nil)
        }

        CommandGroup(after: .sidebar) {
            Toggle("Accessibility Report", isOn: Bindable(workspace).showAccessibilityReport)
                .keyboardShortcut("i", modifiers: [.command, .option])
        }
    }

    private func copy(_ variant: CopyVariant) {
        guard let card = store.selectedCard else { return }
        workspace.copy(card, variant: variant, preferences: preferences.exportPreferences)
    }

    private func export(_ format: ExportFormat) {
        guard let card = store.selectedCard else { return }
        workspace.export(card, format: format, preferences: preferences.exportPreferences)
    }

    private func moveActiveBlock(by offset: Int) {
        guard var card = store.selectedCard, let blockID = activeBlockID else { return }
        card.moveBlock(withID: blockID, by: offset)
        store.update(card)
    }

    private func deleteActiveBlock() {
        guard var card = store.selectedCard, let blockID = activeBlockID else { return }
        card.removeBlock(withID: blockID)
        store.update(card)
        workspace.announce("Block deleted")
    }

    private func importCards() {
        for url in FilePanels.pickOpenURLs(contentTypes: [.json], allowsMultiple: true) {
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                let count = try store.importCards(from: Data(contentsOf: url))
                workspace.announce("Imported \(count) card\(count == 1 ? "" : "s")")
            } catch {
                workspace.announce("Import failed: \(error.localizedDescription)", isError: true)
            }
        }
    }
}
