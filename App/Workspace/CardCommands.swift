import AppKit
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
            .keyboardShortcut(.newCard)

            Button("New Card from Notes…") { workspace.isDraftingFromNotes = true }
                .keyboardShortcut(.newCardFromNotes)
                .disabled(!AppConfiguration.isEnabled(.writingAssistance))

            Menu("New from Template") {
                ForEach(CardTemplate.builtIn) { template in
                    Button(template.name) {
                        store.add(template: template, theme: preferences.defaultTheme, author: preferences.authorName)
                    }
                }
            }
        }

        // Import and Export are siblings in the File menu. Exporting used to
        // live in the Card menu, where nobody went looking for it.
        CommandGroup(replacing: .importExport) {
            Button("Import Cards…") { importCards() }
                .keyboardShortcut(.importCards)

            Menu("Export") {
                ForEach(ExportFormat.allCases) { format in
                    Button("\(format.label)…") { export(format) }
                }
            }
            .disabled(store.selectedCard == nil)
        }

        CommandGroup(replacing: .printItem) {
            Button("Print…") {
                guard let card = store.selectedCard else { return }
                CardPrinter.print(card, width: workspace.cardWidth.points, includeFooter: preferences.includeFooter)
            }
            .keyboardShortcut(.printCard)
            .disabled(store.selectedCard == nil)
        }

        CommandGroup(after: .pasteboard) {
            Button("Paste as Block") { workspace.insertRequest = .paste }
                .keyboardShortcut(.pasteAsBlock)
                .disabled(store.selectedCard == nil)
        }

        CommandMenu("Insert") {
            Group {
                Button("Text") { workspace.insertRequest = .text }
                    .keyboardShortcut(.insertText)
                Button("Metrics") { workspace.insertRequest = .metrics }
                    .keyboardShortcut(.insertMetrics)
                Button("Image…") { workspace.insertRequest = .image }
                    .keyboardShortcut(.insertImage)
            }
            .disabled(store.selectedCard == nil)
        }

        CommandMenu("Card") {
            Group {
                Button("Copy for Email") { copy(.rich) }
                    .keyboardShortcut(.copyForEmail)
                Button("Copy as Image") { copy(.image) }
                    .keyboardShortcut(.copyAsImage)
                Button("Copy as Markdown") { copy(.markdown) }
                Button("Copy for Slack") { copy(.slack) }
                Button("Copy as Plain Text") { copy(.plain) }
                Button("Copy HTML Source") { copy(.html) }

                Divider()

                Button("Move Block Up") { moveSelectedBlock(by: -1) }
                    .keyboardShortcut(.moveBlockUp)
                    .disabled(workspace.selectedBlockID == nil)
                Button("Move Block Down") { moveSelectedBlock(by: 1) }
                    .keyboardShortcut(.moveBlockDown)
                    .disabled(workspace.selectedBlockID == nil)
                Button("Delete Block") { deleteSelectedBlock() }
                    .keyboardShortcut(.deleteBlock)
                    .disabled(workspace.selectedBlockID == nil)

                Divider()

                Button("Check Accessibility") { workspace.reveal(.accessibility) }
                    .keyboardShortcut(.checkAccessibility)
                Button(workspace.speech.isSpeaking ? "Stop Speaking" : "Hear This Card") {
                    guard let card = store.selectedCard else { return }
                    workspace.toggleSpeech(for: card, includeFooter: preferences.includeFooter)
                }
                .keyboardShortcut(.hearThisCard)
                Menu("Simulate Colour Vision") {
                    Picker("Simulate Colour Vision", selection: Bindable(workspace).visionSimulation) {
                        ForEach(VisionSimulation.allCases) { simulation in
                            Text(simulation.label).tag(simulation)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Divider()

                Button("Duplicate Card") {
                    if let id = store.selectedCardID {
                        store.duplicate(id: id)
                    }
                }
                .keyboardShortcut(.duplicateCard)

                Button("Delete Card") {
                    if let id = store.selectedCardID {
                        store.delete(id: id)
                    }
                }
                .keyboardShortcut(.deleteCard)
            }
            .disabled(store.selectedCard == nil)
        }

        CommandGroup(after: .sidebar) {
            Toggle("Format Inspector", isOn: Bindable(workspace).wantsInspector)
                .keyboardShortcut(.formatInspector)
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
        store.update(card, undoManager: NSApp.keyWindow?.undoManager)
        workspace.scrollTarget = blockID
    }

    private func deleteSelectedBlock() {
        guard var card = store.selectedCard, let blockID = workspace.selectedBlockID else { return }
        card.removeBlock(withID: blockID)
        store.update(card, undoManager: NSApp.keyWindow?.undoManager)
        workspace.selectedBlockID = nil
        workspace.announce("Block deleted. Press ⌘Z to undo.")
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
