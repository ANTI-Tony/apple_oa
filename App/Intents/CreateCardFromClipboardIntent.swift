import AppIntents
import ReportCore

/// Shortcuts action: "Create Card from Clipboard".
///
/// Lets users chain the app into automations, for example a weekly Shortcut
/// that copies a spreadsheet range and turns it into a card.
struct CreateCardFromClipboardIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Card from Clipboard"
    static let description = IntentDescription("Creates a new report card from the text, table or image on the clipboard.")
    static let openAppWhenRun = true

    @Parameter(title: "Card Title", default: "Quick update")
    var cardTitle: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard AppConfiguration.isEnabled(.appIntents) else {
            return .result(dialog: "Shortcuts support is disabled in this build.")
        }
        var card = SnippetCard(
            title: cardTitle,
            author: UserPreferences.shared.authorName,
            theme: UserPreferences.shared.defaultTheme
        )
        if let payload = PasteIngestor.read() {
            switch payload {
            case let .image(block): card.blocks = [.image(block)]
            case let .metrics(result, _): card.blocks = [.metrics(MetricsBlock(metrics: result.metrics))]
            case let .text(text): card.blocks = [.text(TextBlock(body: text))]
            }
        }
        CardStore.shared.add(card)
        let count = card.blocks.count
        return .result(dialog: "Created “\(card.title)” with \(count) block\(count == 1 ? "" : "s").")
    }
}

struct ReportingBuilderShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateCardFromClipboardIntent(),
            phrases: ["Create a card from the clipboard in \(.applicationName)"],
            shortTitle: "Card from Clipboard",
            systemImageName: "doc.on.clipboard"
        )
    }
}
