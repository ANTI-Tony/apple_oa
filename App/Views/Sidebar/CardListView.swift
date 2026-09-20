import ReportCore
import SwiftUI

/// Sidebar list of cards with search, context actions and delete-key support.
struct CardListView: View {
    @Environment(CardStore.self) private var store
    @Environment(WorkspaceState.self) private var workspace
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
                        Button("Delete", role: .destructive) { store.delete(id: card.id) }
                    }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search cards")
        .navigationTitle("Cards")
        .onDeleteCommand {
            if let id = store.selectedCardID {
                store.delete(id: id)
                workspace.announce("Card deleted")
            }
        }
        .accessibilityIdentifier("sidebar.cards")
        .overlay {
            if store.cards.isEmpty {
                ContentUnavailableView(
                    "No cards",
                    systemImage: "rectangle.stack",
                    description: Text("Create one with ⌘N.")
                )
            }
        }
    }
}

private struct CardRow: View {
    let card: SnippetCard

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: card.status.symbolName)
                .foregroundStyle(card.status.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.title.isEmpty ? "Untitled" : card.title)
                    .lineLimit(1)
                if !card.subtitle.isEmpty {
                    Text(card.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.title.isEmpty ? "Untitled" : card.title), \(card.status.label)")
    }
}
