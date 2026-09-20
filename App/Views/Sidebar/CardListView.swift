import ReportCore
import SwiftUI

/// The card list: title, context line and a small status dot, like a Notes or
/// Reminders sidebar. Search, context actions and the Delete key all work.
struct CardListView: View {
    @Environment(CardStore.self) private var store
    @Environment(WorkspaceState.self) private var workspace
    @Environment(\.undoManager) private var undoManager
    @State private var searchText = ""

    private var visibleCards: [SnippetCard] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return store.cards }
        return store.cards.filter {
            $0.title.localizedCaseInsensitiveContains(query) || $0.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        @Bindable var store = store
        List(selection: $store.selectedCardID) {
            ForEach(visibleCards) { card in
                CardRow(card: card)
                    .tag(card.id)
                    .contextMenu {
                        Button("Duplicate") { store.duplicate(id: card.id) }
                        Button("Delete", role: .destructive) { store.delete(id: card.id, undoManager: undoManager) }
                    }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search")
        .navigationTitle("Cards")
        .onDeleteCommand {
            if let id = store.selectedCardID {
                store.delete(id: id, undoManager: undoManager)
                workspace.announce("Card deleted. Press ⌘Z to undo.")
            }
        }
        .accessibilityIdentifier("sidebar.cards")
        .overlay {
            if store.cards.isEmpty {
                ContentUnavailableView("No Cards", systemImage: "rectangle.stack", description: Text("Press ⌘N to create one."))
            }
        }
    }
}

private struct CardRow: View {
    let card: SnippetCard
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    private var detail: String {
        let date = card.updatedAt.formatted(.dateTime.month(.abbreviated).day())
        return card.subtitle.isEmpty ? date : "\(date)  \(card.subtitle)"
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Group {
                if differentiateWithoutColor {
                    // System Settings → Accessibility → Display → Differentiate
                    // Without Colour: a distinct shape per status.
                    Image(systemName: card.status.symbolName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Circle()
                        .fill(card.status.tint)
                        .frame(width: 8, height: 8)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.title.isEmpty ? "Untitled" : card.title)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(card.title.isEmpty ? "Untitled" : card.title), \(card.status.label), updated \(detail)")
    }
}
