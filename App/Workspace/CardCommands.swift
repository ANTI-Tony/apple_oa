import ReportCore
import SwiftUI
import UniformTypeIdentifiers

/// Menu bar commands. Every toolbar and inspector action has a menu item, most
/// have a shortcut, so the whole app is operable from the keyboard.
struct CardCommands: Commands {
    let store: CardStore
    let workspace: WorkspaceState
    let preferences: UserPreferences

    private var exportPreferences: ExportPreferences {
        workspace.exportPreferences(from: preferences)
    }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Card") {
                store.add(template: preferences.defaultTemplate, theme: preferences.defaultTheme, author: preferences.authorName)
            }
            .keyboardShortcut("n", modifiers: .command)

            Menu("New from Template") {
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

        CommandGroup(after: .pasteboard) {
            Button("Paste as Block") { workspace.insertRequest = .paste }
                .keyboardShortcut("v", modifiers: [.command, .shift])
                .disabled(store.selectedCard == nil)
        }

        CommandMenu("Insert") {
            Group {
                Button("Text") { workspace.insertRequest = .text }
                    .keyboardShortcut("t", modifiers: [.command, .option])
                Button("Metrics") { workspace.insertRequest = .metrics }
                    .keyboardShortcut("m", modifiers: [.command, .option])
                Button("Image…") { workspace.insertRequest = .image }
                    .keyboardShortcut("g", modifiers: [.command, .option])
            }
            .disabled(store.selectedCard == nil)
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

                Menu("Export") {
                    ForEach(ExportFormat.allCases) { format in
                        Button("\(format.label)…") { export(format) }
                    }
                }

                Divider()

                Button("Move Block Up") { moveSelectedBlock(by: -1) }
                    .keyboardShortcut(.upArrow, modifiers: [.command, .option])
                    .disabled(workspace.selectedBlockID == nil)
                Button("Move Block Down") { moveSelectedBlock(by: 1) }
                    .keyboardShortcut(.downArrow, modifiers: [.command, .option])
                    .disabled(workspace.selectedBlockID == nil)
                Button("Delete Block") { deleteSelectedBlock() }
                    .keyboardShortcut(.delete, modifiers: [.command, .option])
                    .disabled(workspace.selectedBlockID == nil)

                Divider()

                Button("Check Accessibility") { workspace.reveal(.accessibility) }
                    .keyboardShortcut("k", modifiers: [.command, .shift])

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
            Toggle("Format Inspector", isOn: Bindable(workspace).wantsInspector)
                .keyboardShortcut("i", modifiers: [.command, .option])
        }
    }

    private func copy(_ variant: CopyVariant) {
        guard let card = store.selectedCard else { return }
        workspace.copy(card, variant: variant, preferences: exportPreferences)
    }

    private func export(_ format: ExportFormat) {
        guard let card = store.selectedCard else { return }
        workspace.export(card, format: format, preferences: exportPreferences)
    }

    private func moveSelectedBlock(by offset: Int) {
        guard var card = store.selectedCard, let blockID = workspace.selectedBlockID else { return }
        card.moveBlock(withID: blockID, by: offset)
        store.update(card)
        workspace.scrollTarget = blockID
    }

    private func deleteSelectedBlock() {
        guard var card = store.selectedCard, let blockID = workspace.selectedBlockID else { return }
        card.removeBlock(withID: blockID)
        store.update(card)
        workspace.selectedBlockID = nil
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
